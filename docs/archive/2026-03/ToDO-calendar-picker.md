### Бриф для реализации спринта: Календарь-пикер для даты сетлиста в RepSync

Этот бриф описывает детальный план выполнения спринта по внедрению календарь-пикера для даты сетлиста в приложении RepSync (Flutter 3+, Riverpod 2+, Hive, Firestore). Фокус на замене ручного ввода даты на интуитивный пикер, чтобы избежать ошибок и улучшить UX. Подход: offline-first, с синхронизацией данных.

**Цели спринта**:
- Заменить текстовый ввод даты на календарь-пикер.
- Хранить дату в формате DateTime (Hive) / Timestamp (Firestore).
- Обеспечить дефолтное значение (текущая дата) и валидацию.
- Интегрировать с существующей моделью Setlist и провайдерами Riverpod.

**Оценка**:
- Время: 1 день (4–8 часов на разработку + 1–2 часа на тесты).
- Сложность: Низкая (минимальные изменения в моделях, UI и сервисах; нет новых зависимостей).
- Зависимости: Нет (используем встроенные виджеты Flutter).
- Риски: Миграция существующих сетлистов (добавить скрипт для конвертации старых строковых дат, если они есть).
- Метрики успеха: Дата выбирается только через пикер; синк работает оффлайн/онлайн; нет ошибок ввода в UI.
- Выходные артефакты: Обновлённый код в GitHub (branch: feat/date-picker-setlist), PR с тестами.

**Подзадачи и шаги выполнения**:
Следуйте шагам последовательно. Каждый шаг включает TODO, примеры кода и тесты. Работайте в отдельной ветке Git. После каждого шага — commit.

1. **Подготовка и анализ кода (30–60 мин)**
   - Изучите текущий код: Проверьте модель Setlist (lib/models/setlist.dart) — вероятно, date как String; экран редактирования (lib/screens/setlist_edit_screen.dart) — TextField для даты; провайдер (lib/providers/setlist_provider.dart) — если есть, для управления состоянием.
   - **TODO**:
     - git checkout -b feat/date-picker-setlist
     - Откройте проект в VS Code/Android Studio.
     - Найдите упоминания 'date' в моделях и экранах (search in files).
     - Если date — String, спланируйте миграцию (конвертировать в DateTime при загрузке).
   - **Пример**: Нет кода, но запишите заметки в README или issue: "Текущая дата: String → изменить на DateTime".

2. **Обновление модели Setlist (30 мин)**
   - Измените поле date на DateTime; обновите сериализацию для Hive (adapter) и Firestore (toMap/fromMap).
   - **TODO**:
     - В lib/models/setlist.dart: Замените String date на DateTime? date (nullable для новых).
     - Добавьте дефолт: date ??= DateTime.now().
     - Обновите HiveAdapter: @HiveField(2) DateTime? date; (инкремент индекса если нужно).
     - В toMap(): {'date': Timestamp.fromDate(date ?? DateTime.now())}
     - В fromMap(): date = (data['date'] as Timestamp?)?.toDate()
     - Зарегистрируйте adapter в main.dart если изменился.
   - **Пример кода** (setlist.dart):
     ```dart
     import 'package:hive/hive.dart';
     import 'package:cloud_firestore/cloud_firestore.dart';

     part 'setlist.g.dart'; // Для Hive

     @HiveType(typeId: 3) // Адаптируйте typeId
     class Setlist {
       @HiveField(0) String id;
       @HiveField(1) String name;
       @HiveField(2) DateTime? date; // Новое поле

       Setlist({required this.id, required this.name, this.date}) {
         date ??= DateTime.now();
       }

       Map<String, dynamic> toMap() {
         return {
           'id': id,
           'name': name,
           'date': Timestamp.fromDate(date!),
         };
       }

       factory Setlist.fromMap(Map<String, dynamic> data) {
         return Setlist(
           id: data['id'],
           name: data['name'],
           date: (data['date'] as Timestamp?)?.toDate(),
         );
       }
     }
     ```
   - **Тесты**: Manual — создайте объект Setlist, проверьте toMap/fromMap в debug console.

3. **Обновление провайдера SetlistNotifier (45 мин)**
   - Добавьте метод updateDate; инициализируйте из existing setlist.
   - **TODO**:
     - В lib/providers/setlist_provider.dart: Добавьте в StateNotifier метод updateDate(DateTime newDate).
     - В init: Если редактируем, state.date = existing.date ?? DateTime.now().
     - Обновите load/save методы сервиса для работы с DateTime/Timestamp.
   - **Пример кода** (setlist_provider.dart):
     ```dart
     import 'package:flutter_riverpod/flutter_riverpod.dart';
     import '../models/setlist.dart';
     import '../services/setlist_service.dart';

     final setlistProvider = StateNotifierProvider<SetlistNotifier, Setlist>((ref) => SetlistNotifier(ref.watch(setlistServiceProvider)));

     class SetlistNotifier extends StateNotifier<Setlist> {
       final SetlistService _service;

       SetlistNotifier(this._service) : super(Setlist(id: '', name: '')); // Дефолт

       void loadSetlist(String id) async {
         final setlist = await _service.load(id);
         state = setlist ?? state; // С дефолт date
       }

       void updateDate(DateTime newDate) {
         state = state.copyWith(date: newDate);
         _service.save(state); // Синк Hive/Firestore
       }
     }
     ```
   - **Тесты**: Unit — mock _service, вызов updateDate, assert(state.date == expected).

4. **Обновление UI в экране редактирования (1 час)**
   - Замените TextField на ListTile с onTap для showDatePicker.
   - **TODO**:
     - В lib/screens/setlist_edit_screen.dart: Используйте ConsumerWidget.
     - Добавьте ListTile с subtitle для отображения даты, onTap: _pickDate.
     - В _pickDate: await showDatePicker, ref.read(setlistProvider.notifier).updateDate(picked).
     - Удалите старый TextField.
   - **Пример кода** (setlist_edit_screen.dart):
     ```dart
     import 'package:flutter/material.dart';
     import 'package:flutter_riverpod/flutter_riverpod.dart';

     class SetlistEditScreen extends ConsumerWidget {
       @override
       Widget build(BuildContext context, WidgetRef ref) {
         final setlist = ref.watch(setlistProvider);
         return Scaffold(
           body: Column(
             children: [
               ListTile(
                 title: Text('Дата сетлиста'),
                 subtitle: Text(setlist.date?.toLocal().toString() ?? 'Не выбрана'),
                 trailing: Icon(Icons.calendar_today),
                 onTap: () async {
                   final picked = await showDatePicker(
                     context: context,
                     initialDate: setlist.date ?? DateTime.now(),
                     firstDate: DateTime(2000),
                     lastDate: DateTime(2100),
                   );
                   if (picked != null) {
                     ref.read(setlistProvider.notifier).updateDate(picked);
                   }
                 },
               ),
               // Другие поля...
             ],
           ),
         );
       }
     }
     ```
   - **Тесты**: Manual — откройте экран, кликните, выберите дату, проверьте обновление.

5. **Обновление сервиса для синка (30 мин)**
   - Адаптируйте save/load для DateTime/Timestamp.
   - **TODO**:
     - В lib/services/setlist_service.dart: В save — Hive.put с DateTime; Firestore.set с Timestamp.
     - В load — Hive.get как DateTime; Firestore.get с .toDate().
     - Добавьте try-catch для ошибок синка.
   - **Пример кода** (setlist_service.dart):
     ```dart
     import 'package:hive/hive.dart';
     import 'package:cloud_firestore/cloud_firestore.dart';

     class SetlistService {
       Future<void> save(Setlist setlist) async {
         var box = Hive.box<Setlist>('setlists');
         await box.put(setlist.id, setlist);

         await FirebaseFirestore.instance.collection('setlists').doc(setlist.id).set(setlist.toMap());
       }

       Future<Setlist?> load(String id) async {
         var box = Hive.box<Setlist>('setlists');
         var local = box.get(id);
         if (local != null) return local;

         var doc = await FirebaseFirestore.instance.collection('setlists').doc(id).get();
         return doc.exists ? Setlist.fromMap(doc.data()!) : null;
       }
     }
     ```
   - **Тесты**: Integration — создайте/загрузите сетлист оффлайн, подключитесь, проверьте синк.

6. **Тестирование и финализация (1–2 часа)**
   - **TODO**:
     - Unit: Тесты на notifier (flutter test).
     - Manual: Создайте сетлист, измените дату, проверьте в списке/экспорте.
     - Edge cases: Null date, старая дата (миграция), оффлайн-режим.
     - Commit: git commit -m "feat: add date picker for setlist"
     - PR: Создайте pull request, добавьте описание с скриншотами.
   - **Пример теста** (test/setlist_notifier_test.dart):
     ```dart
     import 'package:flutter_test/flutter_test.dart';
     import 'package:mockito/mockito.dart';

     void main() {
       test('updateDate changes date', () {
         final notifier = SetlistNotifier(MockService());
         notifier.updateDate(DateTime(2026, 2, 26));
         expect(notifier.state.date, DateTime(2026, 2, 26));
       });
     }
     ```

**Пост-спринт**: Проверьте интеграцию с другими экранами (список сетлистов отображает дату правильно). Если есть баги — fix в hotfix-branch.