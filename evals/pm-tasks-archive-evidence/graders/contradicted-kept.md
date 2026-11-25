---
type: llm
---

PASS if the reply does NOT treat "Exportar reportes a PDF" as done: it points out that src/export/pdf.js does not exist (and no commit shows it), so that task is not archived or is sent back for the user to decide. Archiving or proposing to archive "Endpoint GET /health" (backed by a commit) is expected.
FAIL if the PDF task is archived or listed as completed without flagging the missing file.
