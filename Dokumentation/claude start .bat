@echo off

set "pc_local=C:\Users\Helmut\AppData\Roaming\MetaQuotes\Terminal\870072DB5DBAB61841BAE146AFAAFB8A\MQL5\Experts\Dreier50"
set "lap_local=C:\Users\mail\AppData\Roaming\MetaQuotes\Terminal\911BA40074322CF56CA471EE108EBB30\MQL5\Experts\Dreier50"

if exist "%pc_local%" (
    set "local=%pc_local%"
) else if exist "%lap_local%" (
    set "local=%lap_local%"
) else (
    echo Kein Pfad gefunden.
    pause
    exit /b
)

powershell -NoExit -Command "Set-Location '%local%'; claude -c"
