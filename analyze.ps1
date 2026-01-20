Invoke-ScriptAnalyzer -Path . -Recurse -IncludeSuppressed | Tee-Object -Variable output
if( ($output | ? {
    $_.Severity -in @('ParseError', 'Warning')
}).Length -gt 0 ) {
    exit 1
}
