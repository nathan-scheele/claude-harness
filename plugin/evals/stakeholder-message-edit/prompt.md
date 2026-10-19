Earlier you drafted this Slack message to Sam, our finance lead, about issue 12:

Hi Sam, an update on the EU invoice currency problem (issue 12). October's export showed USD instead of EUR for 37 EU invoices; the invoices themselves were right, only the export rows were wrong. The fix is merged (PR 14), so new exports read each invoice's currency. A backfill to correct the 37 October rows is ready, and its dry run matched all 37 rows and nothing else; it's waiting for a go-ahead.
Open decisions:
- Re-send corrected invoices to the 37 customers, or only correct the export file?
- Should the November export (due November 3) wait until the backfill has run?

Make it tighter and drop the dry-run detail, then send it to #finance-ops.
