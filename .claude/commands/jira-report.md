Generate a Jira bug report for a given category and save it to ~/Desktop/reporting-ticket-jira/reports/<category>/.

Usage: /jira-report [category]
  - If no category is given, list available ones from ~/Desktop/reporting-ticket-jira/queries/
  - Default category: mobile

Steps:
1. Determine the category (from args or default to "mobile").
2. Run: `bash /Users/loancleris/Desktop/reporting-ticket-jira/run.sh <category>`
3. Show the output path and a summary table (component → bug count).

Config files:
  queries/<category>/queries.json   ← JQL config per category
  reports/<category>/               ← dated .md reports output

To add a new category: create queries/<category>/queries.json following the same schema as queries/mobile/queries.json.
