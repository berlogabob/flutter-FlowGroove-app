/// Repeating song sections and nested practice phrases, from ReapeZoom's
/// repetition graph and spectral hierarchy. Pure Dart over mono PCM.
library;

import 'dart:math';
import 'dart:typed_data';

// AudioGrid's model imports UI transitively. The standalone evaluator uses the
// grid values below; Flutter callers use the existing model without conversion.
import 'song_structure.dart'
    if (dart.library.ui) '../../models/audio_region.dart'
    as model;

/// Standalone grid interface (`bpm` and `offsetMs`), for `dart run` records.
/// Dynamic only in the non-UI branch so static analysis also accepts the app's
/// AudioGrid; Flutter compiles the parameter against the existing model.
typedef AudioGrid = dynamic;

/// Named occurrences, nested phrases, and per-k boundaries (k = 2…10).
class SongStructure {
  const SongStructure({
    required this.sections,
    required this.parts,
    required this.levels,
  });
  final List<({int startMs, int endMs, String label, String name})> sections;
  final List<({int startMs, int endMs, int sectionIndex, String letter})> parts;
  final List<({int k, List<int> boundariesMs})> levels;
}

/// One bar's accumulated chroma, timbre and six streaming texture features.
/// Exposed so the reference's synthetic checks can exercise the same decoder.
typedef StructureUnit = ({
  List<double> chroma,
  List<double> timbre,
  List<double> texture,
});

/// Analyse bars from the first downbeat, matching the Lua feature state.
/// Regions include the pickup and trailing partial bar; null under eight bars.
/// ponytail: 4/4 assumed and functional names are guesses; drifting tempo and
/// ambiguous verse/chorus roles still need the musician's manual map.
SongStructure? analyseStructure(
  Int16List pcm,
  int sampleRate,
  // The non-UI typedef is dynamic; Flutter keeps the model parameter type.
  // ignore: avoid_annotating_with_dynamic
  model.AudioGrid grid,
) {
  // The non-UI interface has just these two fields; keep dynamic at this edge.
  // ignore: avoid_dynamic_calls
  final bpm = grid.bpm as double;
  // ignore: avoid_dynamic_calls
  final offsetMs = grid.offsetMs as int;
  if (sampleRate <= 0 || !bpm.isFinite || bpm <= 0) return null;
  final bar = 240000 / bpm;
  final duration = pcm.length * 1000 / sampleRate;
  final down = offsetMs - (offsetMs / bar).floor() * bar;
  final starts = <double>[];
  for (var t = down; t + 0.99 * bar <= duration; t += bar) {
    starts.add(t);
  }
  if (starts.length < 8) return null;
  // Start filter and onset buckets at the first analysed bar, as Lua does.
  final state = _Texture(sampleRate);
  final spectrum = _Spectrum(sampleRate);
  final units = <StructureUnit>[];
  for (final t in starts) {
    final first = (t * sampleRate / 1000).floor();
    final last = ((t + bar) * sampleRate / 1000).floor().clamp(0, pcm.length);
    final texture = state.read(pcm, first, last);
    final ch = _zeros(12);
    final tm = _zeros(12);
    for (
      var offset = first;
      offset + _fftSize <= last;
      offset += _fftSize ~/ 2
    ) {
      final mags = spectrum.magnitudes(pcm, offset);
      final c = spectrum.chroma(mags);
      final t = spectrum.timbre(mags);
      for (var j = 0; j < 12; j++) {
        ch[j] += c[j];
        tm[j] += t[j];
      }
    }
    units.add((chroma: ch, timbre: tm, texture: texture));
  }
  return analyseStructureUnits(
    units,
    startsMs: starts,
    endMs: duration.round(),
  );
}

const _fftSize = 4096;
List<double> _zeros(int n) => List<double>.filled(n, 0);
double _sq(double x) => x * x;
double _distance(List<double> a, List<double> b) {
  var s = 0.0;
  for (var j = 0; j < a.length; j++) {
    s += _sq(a[j] - b[j]);
  }
  return s;
}

double _median(List<double> a) {
  if (a.isEmpty) return 0;
  final b = [...a]..sort();
  return (b[(b.length - 1) ~/ 2] + b[b.length ~/ 2]) / 2;
}

List<double> _normalize(List<double> a) {
  var s = 0.0;
  for (final x in a) {
    s += x * x;
  }
  s = sqrt(s);
  return [
    for (final x in a)
      if (s > 1e-12) x / s else 0.0,
  ];
}

List<List<double>> _standardize(List<List<double>> rows) {
  final out = [for (final row in rows) _zeros(row.length)];
  for (var j = 0; j < rows.first.length; j++) {
    var mean = 0.0;
    for (final row in rows) {
      mean += row[j];
    }
    mean /= rows.length;
    var v = 0.0;
    for (final row in rows) {
      v += _sq(row[j] - mean);
    }
    final sd = sqrt(v / rows.length);
    for (var i = 0; i < rows.length; i++) {
      out[i][j] = sd > 1e-10 ? (rows[i][j] - mean) / sd : 0;
    }
  }
  return out;
}

class _Texture {
  _Texture(int sr)
    : a1 = 1 - exp(-2 * pi * 200 / sr),
      a2 = 1 - exp(-2 * pi * 2500 / sr);
  final double a1;
  final double a2;
  double lp1 = 0;
  double lp2 = 0;
  double energy = 0;
  double previousLevel = 0;
  int count = 0;
  int blockIndex = 0;
  List<double> read(Int16List pcm, int first, int last) {
    double all = 0;
    double low = 0;
    double mid = 0;
    double high = 0;
    double hits = 0;
    int crossings = 0;
    int blocks = 0;
    for (var i = first; i < last; i++) {
      final s = pcm[i].toDouble();
      lp1 += a1 * (s - lp1);
      lp2 += a2 * (s - lp2);
      all += s * s;
      low += lp1 * lp1;
      mid += _sq(lp2 - lp1);
      high += _sq(s - lp2);
      if (i > first && (s >= 0) != (pcm[i - 1] >= 0)) crossings++;
      energy += s * s;
      count++;
      if (count == 256) {
        final level = log(1 + energy / 256);
        hits += blockIndex > 0 ? max(0, level - previousLevel) : 0;
        previousLevel = level;
        blockIndex++;
        blocks++;
        energy = 0;
        count = 0;
      }
    }
    final n = max(1, last - first);
    return [
      log(1 + all / n),
      log(1 + low / n),
      log(1 + mid / n),
      log(1 + high / n),
      crossings / n,
      hits / max(1, blocks),
    ];
  }
}

class _Spectrum {
  _Spectrum(int sr) : binHz = sr / _fftSize {
    final lo = 2595 * log(1 + 60 / 700) / ln10;
    final hi = 2595 * log(1 + 10000 / 700) / ln10;
    edges = [
      for (var j = 0; j <= 21; j++)
        700 * (pow(10, (lo + (hi - lo) * j / 21) / 2595) - 1),
    ];
    for (var i = 0; i <= _fftSize ~/ 2; i++) {
      final hz = i * binHz;
      classes.add(
        hz >= 80 && hz <= 5000
            ? ((12 * log(hz / 261.6256) / ln2 + 0.5).floor() % 12)
            : -1,
      );
    }
  }
  final double binHz;
  late final List<double> edges;
  final classes = <int>[];
  final hann = [
    for (var i = 0; i < _fftSize; i++)
      0.5 - 0.5 * cos(2 * pi * i / (_fftSize - 1)),
  ];
  final re = Float64List(_fftSize);
  final im = Float64List(_fftSize);
  List<double> magnitudes(Int16List pcm, int first) {
    for (var i = 0; i < _fftSize; i++) {
      re[i] = pcm[first + i] / 32768 * hann[i];
      im[i] = 0;
    }
    var j = 0;
    for (var i = 0; i < _fftSize; i++) {
      if (i < j) {
        final x = re[i];
        re[i] = re[j];
        re[j] = x;
      }
      var m = _fftSize ~/ 2;
      while (m >= 1 && j >= m) {
        j -= m;
        m ~/= 2;
      }
      j += m;
    }
    for (var length = 2; length <= _fftSize; length *= 2) {
      final wr = cos(-2 * pi / length);
      final wi = sin(-2 * pi / length);
      for (var start = 0; start < _fftSize; start += length) {
        double cr = 1;
        double ci = 0;
        for (var k = 0; k < length ~/ 2; k++) {
          final a = start + k;
          final b = a + length ~/ 2;
          final tr = cr * re[b] - ci * im[b];
          final ti = cr * im[b] + ci * re[b];
          re[b] = re[a] - tr;
          im[b] = im[a] - ti;
          re[a] += tr;
          im[a] += ti;
          final next = cr * wr - ci * wi;
          ci = cr * wi + ci * wr;
          cr = next;
        }
      }
    }
    // The action ignores DC/Nyquist. Its FFT scale cancels in normalized
    // chroma and the nonzero DCT coefficients of log-mel energy.
    return [
      0,
      for (var i = 1; i < _fftSize ~/ 2; i++)
        sqrt(re[i] * re[i] + im[i] * im[i]),
    ];
  }

  List<double> chroma(List<double> mags) {
    final ch = _zeros(12);
    for (var i = 0; i < mags.length; i++) {
      final pc = classes[i];
      if (pc >= 0) ch[pc] += mags[i] * mags[i];
    }
    return ch;
  }

  List<double> timbre(List<double> mags) {
    final bands = _zeros(20);
    for (var j = 0; j < 20; j++) {
      for (
        var i = max(0, (edges[j] / binHz).ceil());
        i <= min(mags.length - 1, (edges[j + 2] / binHz).floor());
        i++
      ) {
        final hz = i * binHz;
        final w = hz < edges[j + 1]
            ? (hz - edges[j]) / (edges[j + 1] - edges[j])
            : (edges[j + 2] - hz) / (edges[j + 2] - edges[j + 1]);
        bands[j] += max(0, w) * mags[i] * mags[i];
      }
      bands[j] = log(1e-6 + bands[j]);
    }
    return [for (var c = 1; c <= 12; c++) _dct(bands, c)];
  }

  double _dct(List<double> bands, int c) {
    var s = 0.0;
    for (var j = 0; j < 20; j++) {
      s += bands[j] * cos(pi * c * (j + 0.5) / 20);
    }
    return s * sqrt(2 / 20);
  }
}

/// Symmetric eigendecomposition, ascending eigenvalues; vectors are columns.
/// Input is copied. Exposed for the reference's known-matrix/residual checks.
({List<double> values, List<List<double>> vectors}) structureJacobi(
  List<List<double>> matrix,
) {
  final n = matrix.length;
  final a = [
    for (final row in matrix) [...row],
  ];
  final v = [
    for (var i = 0; i < n; i++)
      [
        for (var j = 0; j < n; j++)
          if (i == j) 1.0 else 0.0,
      ],
  ];
  for (var sweep = 0; sweep < 100; sweep++) {
    var largest = 0.0;
    for (var p = 0; p < n - 1; p++) {
      for (var q = p + 1; q < n; q++) {
        final apq = a[p][q];
        largest = max(largest, apq.abs());
        if (apq.abs() <= 1e-14) continue;
        final tau = (a[q][q] - a[p][p]) / (2 * apq);
        final t = (tau >= 0 ? 1 : -1) / (tau.abs() + sqrt(1 + tau * tau));
        final c = 1 / sqrt(1 + t * t);
        final s = t * c;
        a[p][p] -= t * apq;
        a[q][q] += t * apq;
        a[p][q] = 0;
        a[q][p] = 0;
        for (var r = 0; r < n; r++) {
          if (r != p && r != q) {
            final x = a[r][p];
            final y = a[r][q];
            a[r][p] = c * x - s * y;
            a[p][r] = a[r][p];
            a[r][q] = s * x + c * y;
            a[q][r] = a[r][q];
          }
          final x = v[r][p];
          final y = v[r][q];
          v[r][p] = c * x - s * y;
          v[r][q] = s * x + c * y;
        }
      }
    }
    if (largest < 1e-12) break;
    if (sweep == 99) throw StateError('Jacobi did not converge');
  }
  final order = [for (var i = 0; i < n; i++) i]
    ..sort((i, j) => a[i][i].compareTo(a[j][j]));
  return (
    values: [for (final i in order) a[i][i]],
    vectors: [
      for (var i = 0; i < n; i++) [for (final j in order) v[i][j]],
    ],
  );
}

({List<int> labels, double cost}) _kmeans(List<List<double>> rows, int k) {
  final n = rows.length;
  var seed = 17;
  double random() {
    seed = (1664525 * seed + 1013904223) % 4294967296;
    return seed / 4294967296;
  }

  var best = <int>[];
  var bestCost = double.infinity;
  for (var trial = 0; trial < 5; trial++) {
    final centers = [
      [...rows[(random() * n).floor()]],
    ];
    for (var c = 1; c < k; c++) {
      final ds = [
        for (final row in rows)
          centers.map((center) => _distance(row, center)).reduce(min),
      ];
      var x = random() * ds.reduce((a, b) => a + b);
      var pick = n - 1;
      for (var i = 0; i < n; i++) {
        x -= ds[i];
        if (x <= 0) {
          pick = i;
          break;
        }
      }
      centers.add([...rows[pick]]);
    }
    final labels = List<int>.filled(n, -1);
    for (var iteration = 0; iteration < 100; iteration++) {
      final sums = [for (var c = 0; c < k; c++) _zeros(rows.first.length)];
      final counts = List<int>.filled(k, 0);
      var changed = false;
      for (var i = 0; i < n; i++) {
        var label = 0;
        var d = double.infinity;
        for (var c = 0; c < k; c++) {
          final dd = _distance(rows[i], centers[c]);
          if (dd < d) {
            label = c;
            d = dd;
          }
        }
        if (labels[i] != label) changed = true;
        labels[i] = label;
        counts[label]++;
        for (var j = 0; j < rows[i].length; j++) {
          sums[label][j] += rows[i][j];
        }
      }
      for (var c = 0; c < k; c++) {
        if (counts[c] > 0) {
          for (var j = 0; j < rows.first.length; j++) {
            centers[c][j] = sums[c][j] / counts[c];
          }
        } else {
          var far = 0;
          var dd = -1.0;
          for (var i = 0; i < n; i++) {
            final d = _distance(rows[i], centers[labels[i]]);
            if (d > dd) {
              far = i;
              dd = d;
            }
          }
          centers[c] = [...rows[far]];
        }
      }
      if (!changed) break;
    }
    var cost = 0.0;
    for (var i = 0; i < n; i++) {
      cost += _distance(rows[i], centers[labels[i]]);
    }
    if (cost < bestCost) {
      best = labels;
      bestCost = cost;
    }
  }
  return (labels: best, cost: bestCost);
}

({List<List<double>> harmonic, List<List<double>> local}) _features(
  List<StructureUnit> units,
) {
  final harmonic = _standardize([
    for (final u in units) [..._normalize(u.chroma), ...u.timbre],
  ]);
  final local = _standardize([
    for (final u in units) [...u.timbre, ...u.texture],
  ]);
  return (
    harmonic: [
      for (var i = 0; i < units.length; i++)
        _normalize([
          for (var delay = 0; delay < 3; delay++)
            ...harmonic[max(0, i - delay)],
        ]),
    ],
    local: local,
  );
}

({List<double> values, List<List<double>> vectors}) _graph(
  List<StructureUnit> units,
) {
  final n = units.length;
  final f = _features(units);
  final ds = [
    for (var i = 0; i < n; i++)
      [for (var j = 0; j < n; j++) _distance(f.harmonic[i], f.harmonic[j]) / 2],
  ];
  final kn = min(n - 1, 1 + 2 * (log(n) / ln2).ceil());
  final neighbors = <Set<int>>[];
  for (var i = 0; i < n; i++) {
    final order =
        [
          for (var j = 0; j < n; j++)
            if ((i - j).abs() > 3) j,
        ]..sort((a, b) {
          final cmp = ds[i][a].compareTo(ds[i][b]);
          return cmp == 0 ? a.compareTo(b) : cmp;
        });
    neighbors.add(order.take(kn).toSet());
  }
  final r = [
    for (var i = 0; i < n; i++)
      [
        for (var j = 0; j < n; j++)
          if (neighbors[i].contains(j) && neighbors[j].contains(i))
            exp(-ds[i][j])
          else
            0.0,
      ],
  ];
  final filtered = [
    for (var i = 0; i < n; i++)
      [
        for (var j = 0; j < n; j++)
          _median([
            for (var d = -1; d <= 1; d++)
              if (i + d >= 0 && i + d < n && j + d >= 0 && j + d < n)
                r[i + d][j + d],
          ]),
      ],
  ];
  final pathdist = [
    for (var i = 0; i < n - 1; i++) _distance(f.local[i], f.local[i + 1]),
  ];
  final scale = max(1e-12, _median(pathdist));
  final path = _zeros(n);
  final degree = [for (final row in filtered) row.reduce((a, b) => a + b)];
  final edges = [for (var i = 0; i < n - 1; i++) exp(-pathdist[i] / scale)];
  for (var i = 0; i < n - 1; i++) {
    path[i] += edges[i];
    path[i + 1] += edges[i];
  }
  double numerator = 0;
  double denominator = 0;
  for (var i = 0; i < n; i++) {
    final total = degree[i] + path[i];
    numerator += path[i] * total;
    denominator += total * total;
  }
  final mu = denominator > 0 ? numerator / denominator : 0.5;
  final a = [
    for (var i = 0; i < n; i++)
      [
        for (var j = 0; j < n; j++)
          mu * filtered[i][j] +
              (1 - mu) * ((i - j).abs() == 1 ? edges[min(i, j)] : 0),
      ],
  ];
  final d = [for (final row in a) row.reduce((a, b) => a + b)];
  return structureJacobi([
    for (var i = 0; i < n; i++)
      [
        for (var j = 0; j < n; j++)
          (i == j ? 1.0 : 0.0) -
              (d[i] * d[j] > 0 ? a[i][j] / sqrt(d[i] * d[j]) : 0),
      ],
  ]);
}

class _Segment {
  _Segment(this.first, this.last, [this.label = '']);
  final int first;
  int last;
  String label;
  String name = '';
}

List<_Segment> _merge(List<_Segment> segments) {
  final out = <_Segment>[];
  for (final s in segments) {
    if (out.isNotEmpty && out.last.label == s.label) {
      out.last.last = s.last;
    } else {
      out.add(s);
    }
  }
  return out;
}

({List<_Segment> segments, double cost}) _segment(
  List<int> labels,
  int minimum,
  double target,
  int maximum,
) {
  final n = labels.length;
  final k = labels.reduce(max) + 1;
  final dp = List<double>.filled(n + 1, double.infinity)..[0] = 0;
  final back = List<_Segment?>.filled(n + 1, null);
  for (var last = 1; last <= n; last++) {
    final counts = List<int>.filled(k, 0);
    var dominant = 0;
    for (var length = 1; length <= min(last, maximum); length++) {
      final l = labels[last - length];
      counts[l]++;
      dominant = max(dominant, counts[l]);
      if (length >= minimum || length == n) {
        final first = last - length;
        final prior = 0.35 * _sq((length - target) / target);
        final score = dp[first] + length - dominant + prior;
        if (score < dp[last]) {
          var best = 0;
          for (var c = 1; c < k; c++) {
            if (counts[c] > counts[best]) best = c;
          }
          dp[last] = score;
          back[last] = _Segment(first, last, '$best');
        }
      }
    }
  }
  if (back[n] == null) {
    return (segments: [_Segment(0, n, '${labels.first}')], cost: 0);
  }
  final result = <_Segment>[];
  for (var i = n; i > 0; i = back[i]!.first) {
    result.insert(0, back[i]!);
  }
  return (segments: _merge(result), cost: dp[n] / n);
}

List<_Segment> _refine(
  List<_Segment> sections,
  List<StructureUnit> units, {
  bool anchored = false,
  double noveltyThreshold = 2,
}) {
  final f = _features(units);
  final n = units.length;
  final rows = f.local;
  final harmony = f.harmonic;
  final novelty = _zeros(n + 1);
  for (var cut = 1; cut < n; cut++) {
    var d = 0.0;
    for (var j = 0; j < rows.first.length; j++) {
      double before = 0;
      double after = 0;
      final w = min(2, min(cut, n - cut));
      for (var t = 0; t < w; t++) {
        before += rows[cut - t - 1][j];
        after += rows[cut + t][j];
      }
      d += _sq((after - before) / w);
    }
    novelty[cut] = sqrt(d / rows.first.length);
  }
  final population = novelty.sublist(1, n);
  final mean = population.reduce((a, b) => a + b) / population.length;
  final threshold =
      mean +
      noveltyThreshold *
          sqrt(
            population.map((x) => _sq(x - mean)).reduce((a, b) => a + b) /
                population.length,
          );
  final candidates = <int>{};
  for (final s in sections.skip(1)) {
    var cut = s.first;
    if (anchored && cut % 8 == 4) {
      var best = cut;
      for (final t in [cut - 4, cut + 4]) {
        if (t >= 4 &&
            t <= n - 4 &&
            novelty[t] > novelty[cut] &&
            (best == cut || novelty[t] > novelty[best])) {
          best = t;
        }
      }
      cut = best;
    }
    candidates.add(cut);
  }
  for (var cut = 4; cut <= n - 4; cut++) {
    if (novelty[cut] >= threshold &&
        novelty[cut] >= novelty[cut - 1] &&
        novelty[cut] >= novelty[cut + 1]) {
      final snapped = (cut / 2 + 0.5).floor() * 2;
      if (snapped >= 4 && n - snapped >= 4) candidates.add(snapped);
    }
  }
  final order = candidates.toList()
    ..sort((a, b) {
      final c = novelty[b].compareTo(novelty[a]);
      return c == 0 ? a.compareTo(b) : c;
    });
  final cuts = [0, n];
  for (final cut in order) {
    final minimum = novelty[cut] >= threshold ? 2 : 4;
    if (cuts.every((other) => (other - cut).abs() >= minimum)) cuts.add(cut);
  }
  cuts.sort();
  final result = <_Segment>[];
  final means = <List<double>>[];
  for (var i = 0; i < cuts.length - 1; i++) {
    final first = cuts[i];
    final last = cuts[i + 1];
    final width = rows.first.length + harmony.first.length;
    final row = _zeros(2 * width);
    for (var t = first; t < last; t++) {
      final half = min(1, (2 * (t - first) / (last - first)).floor());
      for (var j = 0; j < rows[t].length; j++) {
        row[half * width + j] += rows[t][j] * 2 / (last - first);
      }
      for (var j = 0; j < harmony[t].length; j++) {
        row[half * width + rows.first.length + j] +=
            harmony[t][j] * 2 / (last - first);
      }
    }
    means.add(row);
    result.add(_Segment(first, last));
  }
  final distances = [
    for (var i = 0; i < means.length; i++)
      for (var j = i + 1; j < means.length; j++)
        sqrt(_distance(means[i], means[j]) / means[i].length),
  ];
  final limit = 0.5 * _median(distances);
  final centers = <List<double>>[];
  for (var i = 0; i < means.length; i++) {
    var best = -1;
    var d = double.infinity;
    for (var c = 0; c < centers.length; c++) {
      final x = sqrt(_distance(means[i], centers[c]) / means[i].length);
      if (x < d) {
        best = c;
        d = x;
      }
    }
    if (best < 0 || d >= limit) {
      centers.add(means[i]);
      best = centers.length - 1;
    }
    result[i].label = '${best + 1}';
  }
  return _merge(result);
}

List<_Segment> _mergeTail(List<_Segment> sections) {
  if (sections.length >= 2) {
    final a = sections[sections.length - 2];
    final b = sections.last;
    if (b.last - a.first <= 9) {
      a.last = b.last;
      sections.removeLast();
    }
  }
  return sections;
}

List<_Segment> _mergePairs(List<_Segment> sections) {
  final count = <String, int>{};
  final pairs = <String, int>{};
  for (var i = 0; i < sections.length; i++) {
    final s = sections[i];
    count[s.label] = (count[s.label] ?? 0) + 1;
    if (i + 1 < sections.length) {
      final key = '${s.label}:${sections[i + 1].label}';
      pairs[key] = (pairs[key] ?? 0) + 1;
    }
  }
  final out = <_Segment>[];
  for (var i = 0; i < sections.length; i++) {
    final a = sections[i];
    final b = i + 1 < sections.length ? sections[i + 1] : null;
    if (b != null &&
        count[a.label]! >= 2 &&
        count[a.label] == count[b.label] &&
        pairs['${a.label}:${b.label}'] == count[a.label]) {
      out.add(_Segment(a.first, b.last, '${a.label}:${b.label}'));
      i++;
    } else {
      out.add(a);
    }
  }
  return out;
}

List<({int first, int last, int section, String letter})> _practice(
  List<_Segment> sections,
  List<StructureUnit> units,
  List<int> fine,
  int stride, {
  int phraseTarget = 4,
}) {
  final ch = [for (final u in units) _normalize(u.chroma)];
  final jumps = [
    0.0,
    for (var i = 1; i < units.length; i++) _distance(ch[i - 1], ch[i]),
  ];
  final scale = max(1e-9, _median(jumps.sublist(1)));
  final occurrences = <String, int>{};
  for (final s in sections) {
    occurrences[s.label] = (occurrences[s.label] ?? 0) + 1;
  }
  final parts = <({int first, int last, int section, String letter})>[];
  for (var si = 0; si < sections.length; si++) {
    final s = sections[si];
    final target = si == sections.length - 1 && occurrences[s.label] == 1
        ? 2
        : phraseTarget;
    bool validLength(int length, int last) =>
        length == 2 ||
        length == 4 ||
        length == 8 ||
        (last == s.last &&
            (s.last - s.first).isOdd &&
            length.isOdd &&
            length <= 8);
    final dp = List<double>.filled(s.last + 1, double.infinity)..[s.first] = 0;
    final back = List<_Segment?>.filled(s.last + 1, null);
    for (var last = s.first + 1; last <= s.last; last++) {
      final counts = <int, int>{};
      var dominant = 0;
      for (var length = 1; length <= min(8, last - s.first); length++) {
        final first = last - length;
        final l = fine[first ~/ stride];
        counts[l] = (counts[l] ?? 0) + 1;
        dominant = max(dominant, counts[l]!);
        if (validLength(length, last)) {
          final novelty = first > s.first ? min(2, jumps[first] / scale) : 0;
          var cost =
              dp[first] +
              0.5 +
              0.25 * (length - dominant) +
              0.35 * _sq((length - target) / target) -
              0.15 * novelty;
          if ((first - s.first) % target != 0) cost += 0.4;
          if (cost < dp[last]) {
            dp[last] = cost;
            back[last] = _Segment(first, last);
          }
        }
      }
    }
    var decoded = <_Segment>[];
    var last = s.last;
    while (last > s.first && back[last] != null) {
      decoded.insert(0, back[last]!);
      last = back[last]!.first;
    }
    if (decoded.isEmpty) decoded = [_Segment(s.first, s.last)];
    final grid = <_Segment>[];
    var first = s.first;
    while (first < s.last) {
      var length = min(s.last - first, target);
      if (s.last - first - length < 2) length = s.last - first;
      grid.add(_Segment(first, first + length));
      first += length;
    }
    double cost(List<_Segment> plan) {
      var value = 0.0;
      for (final p in plan) {
        final counts = <int, int>{};
        var dominant = 0;
        for (var i = p.first; i < p.last; i++) {
          final l = fine[i ~/ stride];
          counts[l] = (counts[l] ?? 0) + 1;
          dominant = max(dominant, counts[l]!);
        }
        final length = p.last - p.first;
        if (!validLength(length, p.last)) return double.infinity;
        value +=
            0.5 +
            0.25 * (length - dominant) +
            0.35 * _sq((length - target) / target);
        if (p.first > s.first) value -= 0.15 * min(2, jumps[p.first] / scale);
        if ((p.first - s.first) % target != 0) value += 0.4;
      }
      return value;
    }

    if (cost(grid) <= cost(decoded)) decoded = grid;
    if (si == sections.length - 1) {
      for (var i = decoded.length - 1; i >= 1; i--) {
        if (units[decoded[i].first].texture[0] <
                units[s.first].texture[0] - 8 &&
            validLength(
              decoded[i].last - decoded[i - 1].first,
              decoded[i].last,
            )) {
          decoded[i - 1].last = decoded[i].last;
          decoded.removeAt(i);
        }
      }
    }
    final letters = <int, String>{};
    for (final p in decoded) {
      final votes = <int, int>{};
      int? best;
      for (var i = p.first; i < p.last; i++) {
        final l = fine[i ~/ stride];
        votes[l] = (votes[l] ?? 0) + 1;
        if (best == null || votes[l]! > votes[best]!) best = l;
      }
      final letter = letters.putIfAbsent(
        best!,
        () => String.fromCharCode(97 + letters.length),
      );
      parts.add((first: p.first, last: p.last, section: si, letter: letter));
    }
  }
  return parts;
}

/// Reference decoder seam: zero-based bar boundaries after local refinement.
List<int> structureRefineBoundaries(
  List<StructureUnit> units,
  List<int> cuts, {
  bool anchored = false,
  double noveltyThreshold = 2,
}) => [
  for (final s in _refine(
    [
      for (var i = 0; i < cuts.length - 1; i++)
        _Segment(cuts[i], cuts[i + 1], '$i'),
    ],
    units,
    anchored: anchored,
    noveltyThreshold: noveltyThreshold,
  ))
    s.last,
];

/// Reference decoder seam: phrase boundaries for supplied repeated sections.
List<int> structurePracticeBoundaries(
  List<StructureUnit> units,
  List<int> fine, {
  List<int>? sectionEnds,
  int phraseTarget = 4,
}) {
  final ends = [0, ...?sectionEnds];
  if (ends.length == 1) ends.add(units.length);
  return [
    for (final p in _practice(
      [
        for (var i = 0; i < ends.length - 1; i++)
          _Segment(ends[i], ends[i + 1], '1'),
      ],
      units,
      fine,
      1,
      phraseTarget: phraseTarget,
    ))
      p.last,
  ];
}

void _nameSections(List<_Segment> sections, List<StructureUnit> units) {
  final count = <String, int>{};
  final energy = <String, double>{};
  final total = <String, int>{};
  for (final s in sections) {
    count[s.label] = (count[s.label] ?? 0) + 1;
    for (var i = s.first; i < s.last; i++) {
      energy[s.label] = (energy[s.label] ?? 0) + units[i].texture[0];
      total[s.label] = (total[s.label] ?? 0) + 1;
    }
  }
  String? chorus;
  String? verse;
  var highest = double.negativeInfinity;
  for (final l in count.keys) {
    final e = energy[l]! / total[l]!;
    if (count[l]! > 1 &&
        (e > highest || (e == highest && l.compareTo(chorus ?? 'nil') < 0))) {
      chorus = l;
      highest = e;
    }
  }
  final votes = <String, int>{};
  for (var i = 1; i < sections.length; i++) {
    if (sections[i].label == chorus) {
      final l = sections[i - 1].label;
      if (l != chorus && count[l]! > 1) votes[l] = (votes[l] ?? 0) + 1;
    }
  }
  for (final l in votes.keys) {
    if (verse == null ||
        votes[l]! > votes[verse]! ||
        (votes[l] == votes[verse] && l.compareTo(verse) < 0)) {
      verse = l;
    }
  }
  final originals = [for (final s in sections) s.label];
  final names = <String, int>{};
  final letters = <String, String>{};
  for (var i = 0; i < sections.length; i++) {
    final s = sections[i];
    final l = s.label;
    final letter = letters.putIfAbsent(
      l,
      () => String.fromCharCode(65 + letters.length),
    );
    final String name;
    if (l == chorus) {
      name = 'Chorus';
    } else if (l == verse) {
      name = 'Verse';
    } else if (i > 0 &&
        i < sections.length - 1 &&
        originals[i - 1] == verse &&
        originals[i + 1] == chorus &&
        s.last - s.first <= 8) {
      name = 'Pre-chorus';
    } else if (count[l] == 1 && i == 0) {
      name = 'Intro';
    } else if (count[l] == 1 && i == sections.length - 1) {
      name = 'Outro';
    } else if (count[l] == 1 && s.first + 1 > units.length / 2) {
      name = 'Bridge';
    } else {
      name = 'Part $letter';
    }
    names[name] = (names[name] ?? 0) + 1;
    s
      ..name = '$name ${names[name]}'
      ..label = letter;
  }
}

/// Decode bar features directly; used by the reference's synthetic self-test.
/// Unit times are file-relative ms; sectionIndex is zero-based. Levels retain
/// each spectral k's boundaries, in increasing k order (coarse to fine).
SongStructure analyseStructureUnits(
  List<StructureUnit> sourceUnits, {
  required List<double> startsMs,
  required int endMs,
}) {
  var offset = 0;
  if (sourceUnits.isNotEmpty) {
    final energy = [for (final u in sourceUnits) u.texture[1]];
    final lo = energy.take(sourceUnits.length ~/ 3).fold(double.infinity, min);
    final contrast = _median(energy) - lo;
    final entry = energy.indexWhere((e) => e >= lo + 0.5 * contrast);
    if (contrast >= 4 && entry >= 1 && entry + 1 <= sourceUnits.length / 3) {
      offset = entry;
    }
  }
  final units = sourceUnits.sublist(offset);
  final n = units.length;
  if (n == 0) return const SongStructure(sections: [], parts: [], levels: []);
  var coarse = units;
  var stride = 1;
  while (coarse.length > 256) {
    List<double> average(List<double> a, List<double> b) => [
      for (var j = 0; j < a.length; j++) (a[j] + b[j]) / 2,
    ];
    coarse = [
      for (var i = 0; i < coarse.length; i += 2)
        (
          chroma: average(
            coarse[i].chroma,
            coarse[min(i + 1, coarse.length - 1)].chroma,
          ),
          timbre: average(
            coarse[i].timbre,
            coarse[min(i + 1, coarse.length - 1)].timbre,
          ),
          texture: average(
            coarse[i].texture,
            coarse[min(i + 1, coarse.length - 1)].texture,
          ),
        ),
    ];
    stride *= 2;
  }
  if (coarse.length == 1) {
    return SongStructure(
      sections: [(startMs: 0, endMs: endMs, label: 'A', name: 'Intro 1')],
      parts: [(startMs: 0, endMs: endMs, sectionIndex: 0, letter: 'a')],
      levels: [],
    );
  }
  final eigen = _graph(coarse);
  final levels = <({int k, List<int> labels, List<_Segment> segments})>[];
  var chosen = 0;
  var score = double.infinity;
  final minlen = max(1, (4 / stride).ceil());
  for (var k = 2; k <= min(10, coarse.length); k++) {
    final rows = [
      for (final v in eigen.vectors) _normalize(v.take(k).toList()),
    ];
    final clustered = _kmeans(rows, k);
    final seg = _segment(
      clustered.labels,
      minlen,
      max(minlen, 8 / stride).toDouble(),
      max(minlen, 32 ~/ stride),
    );
    final mean = coarse.length / seg.segments.length;
    final duration = log(max(1, mean) / (8 / stride)).abs();
    final gap =
        eigen.values[min(k, eigen.values.length - 1)] - eigen.values[k - 1];
    final quality = seg.cost + 0.3 * duration - 2 * gap + 0.15 * (k - 6).abs();
    levels.add((k: k, labels: clustered.labels, segments: seg.segments));
    if (quality < score) {
      chosen = levels.length - 1;
      score = quality;
    }
  }
  final selected = levels[chosen];
  var sections = [
    for (final s in selected.segments)
      _Segment(s.first * stride, min(n, s.last * stride), s.label),
  ];
  final snapped = <_Segment>[];
  for (final s in sections) {
    final first = (s.first / 4 + 0.5).floor() * 4;
    if (first < n && (snapped.isEmpty || first > snapped.last.first)) {
      snapped.add(_Segment(first, n, s.label));
    }
  }
  for (var i = 0; i < snapped.length - 1; i++) {
    snapped[i].last = snapped[i + 1].first;
  }
  double phraseScore(List<_Segment> plan) {
    double errors = 0;
    double phase = 0;
    for (var i = 0; i < plan.length; i++) {
      final s = plan[i];
      for (var u = s.first; u < s.last; u++) {
        if ('${selected.labels[u ~/ stride]}' != s.label) errors++;
      }
      if (i > 0) {
        final p = s.first % 4;
        phase += min(p, 4 - p) / 2;
      }
    }
    return errors / n + 0.4 * phase / max(1, plan.length - 1);
  }

  if (phraseScore(snapped) <= phraseScore(sections)) sections = snapped;
  sections = _mergePairs(
    _mergeTail(_refine(sections, units, anchored: offset > 0)),
  );
  var parts = _practice(sections, units, levels.last.labels, stride);
  if (offset > 0) {
    sections = [
      _Segment(0, offset, '0'),
      for (final s in sections)
        _Segment(s.first + offset, s.last + offset, s.label),
    ];
    final intro = <({int first, int last, int section, String letter})>[];
    for (var first = 0; first < offset;) {
      var length = min(8, offset - first);
      if (length == 6) length = 4;
      intro.add((first: first, last: first + length, section: 0, letter: 'a'));
      first += length;
    }
    parts = [
      ...intro,
      for (final p in parts)
        (
          first: p.first + offset,
          last: p.last + offset,
          section: p.section + 1,
          letter: p.letter,
        ),
    ];
  }
  _nameSections(sections, sourceUnits);
  int time(int index) => index == 0
      ? 0
      : index >= sourceUnits.length
      ? endMs
      : startsMs[index].round();
  return SongStructure(
    sections: [
      for (final s in sections)
        (
          startMs: time(s.first),
          endMs: time(s.last),
          label: s.label,
          name: s.name,
        ),
    ],
    parts: [
      for (final p in parts)
        (
          startMs: time(p.first),
          endMs: time(p.last),
          sectionIndex: p.section,
          letter: p.letter,
        ),
    ],
    levels: [
      for (final level in levels)
        (
          k: level.k,
          boundariesMs: [
            if (offset > 0) time(offset),
            for (final s in level.segments.skip(1))
              time(s.first * stride + offset),
          ],
        ),
    ],
  );
}
