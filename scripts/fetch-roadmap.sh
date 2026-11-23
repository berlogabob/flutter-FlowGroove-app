#!/bin/bash
# fetch-roadmap.sh — snapshot GitHub Project #8 into site/data/roadmap.json
# so the Hugo site can render the kanban board on-page (GitHub blocks iframing).
# Needs `gh` authed with the `project` scope. On failure, keeps the existing
# data file so a deploy never breaks just because the API hiccuped.
set -e
cd "$(dirname "$0")/.."
OWNER=berlogabob
NUMBER=8
OUT=site/data/roadmap.json

read -r -d '' QUERY <<'GQL' || true
query($login:String!, $number:Int!, $endCursor:String){
  user(login:$login){
    projectV2(number:$number){
      title
      field(name:"Status"){ ... on ProjectV2SingleSelectField { options { name } } }
      items(first:100, after:$endCursor){
        pageInfo{ hasNextPage endCursor }
        nodes{
          content{
            __typename
            ... on Issue        { title url number state }
            ... on PullRequest  { title url number state }
            ... on DraftIssue   { title }
          }
          fieldValueByName(name:"Status"){
            ... on ProjectV2ItemFieldSingleSelectValue { name }
          }
        }
      }
    }
  }
}
GQL

# --paginate follows pageInfo.endCursor; --slurp collects every page.
if ! gh api graphql --paginate --slurp -f query="$QUERY" -F login="$OWNER" -F number="$NUMBER" \
  | jq '.[0].data.user.projectV2 as $p | {
      title: $p.title,
      order: (($p.field.options | map(.name)) + ["No Status"]),
      items: [ .[].data.user.projectV2.items.nodes[] | {
        title:  (.content.title // "Untitled"),
        url:    (.content.url // ""),
        number: (.content.number // null),
        type:   (.content.__typename // "DraftIssue"),
        state:  (.content.state // ""),
        status: (.fieldValueByName.name // "No Status")
      }]
    }' > "$OUT.tmp"; then
  echo "⚠️  roadmap fetch failed — keeping existing $OUT"
  rm -f "$OUT.tmp"
  exit 0
fi
mv "$OUT.tmp" "$OUT"
echo "✅ roadmap snapshot → $OUT ($(jq '.items | length' "$OUT") items)"
