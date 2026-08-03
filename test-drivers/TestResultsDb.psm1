<#
Helper para asegurar el schema. Se llama con cada corrida — CREATE TABLE IF NOT EXISTS
es idempotente, así que no hace falta un script de inicialización separado.
#>

function Initialize-TestResultsDb {
    param([string]$DatabasePath)

    $Query = @"
CREATE TABLE IF NOT EXISTS ExecutionLogs (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    RunId TEXT NOT NULL,
    RunTimestamp TEXT,
    MacAddress TEXT NOT NULL,
    LogLevel TEXT,
    TestName TEXT,
    Message TEXT NOT NULL,
    IsStructured INTEGER NOT NULL
);
"@
    Invoke-SqliteQuery -DataSource $DatabasePath -Query $Query
}

function Save-TestLogsToSqlite {
    param(
        [string]$LogDir,
        [string]$DatabasePath,
        [string]$RunId
    )

    if (-not (Get-Module -ListAvailable -Name PSSQLite)) {
        Write-Warning "Módulo PSSQLite no disponible. Los logs quedan en $LogDir sin persistir a base de datos (fallback: se mantiene el archivado en carpeta)."
        return $false
    }
    Import-Module PSSQLite -ErrorAction Stop

    Initialize-TestResultsDb -DatabasePath $DatabasePath

    $Pattern = '^\[(?<Timestamp>[^\]]+)\]\s+\[(?<Level>[^\]]+)\]\s+\[(?<Test>[^\]]+)\]\s+(?<Message>.*)$'
    $LogFiles = Get-ChildItem -Path $LogDir -Filter "*.log" -ErrorAction SilentlyContinue

    foreach ($File in $LogFiles) {
        $IsRawOutputFile = $File.Name -like "RAWOUTPUT_*"
        $RawMac = $File.Name.Split('_')[0]
        $MacAddress = if ($IsRawOutputFile) { 'N/A (raw output)' } else { $RawMac }

        $Lines = Get-Content -Path $File.FullName

        foreach ($Line in $Lines) {
            if ($Line -match $Pattern) {
                # Los archivos RAWOUTPUT_* capturan TODO el stdout del proceso hijo,
                if ($IsRawOutputFile) { continue }

                Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
INSERT INTO ExecutionLogs (RunId, RunTimestamp, MacAddress, LogLevel, TestName, Message, IsStructured)
VALUES (@RunId, @Timestamp, @Mac, @Level, @Test, @Message, 1);
"@ -SqlParameters @{
                    RunId     = $RunId
                    Timestamp = $Matches.Timestamp
                    Mac       = $MacAddress
                    Level     = $Matches.Level
                    Test      = $Matches.Test
                    Message   = $Matches.Message
                }
            } elseif ($Line.Trim()) {
                # Líneas no estructuradas: en archivos RAWOUTPUT los queremos capturar
                Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
INSERT INTO ExecutionLogs (RunId, RunTimestamp, MacAddress, LogLevel, TestName, Message, IsStructured)
VALUES (@RunId, NULL, @Mac, NULL, NULL, @Message, 0);
"@ -SqlParameters @{
                    RunId   = $RunId
                    Mac     = $MacAddress
                    Message = $Line
                }
            }
        }
    }

    return $true
}
