@echo off
rem Copy the built skin (out\YataiDONSimpleStyle) into Z-DON's Skins folder. Run after build.py.
robocopy "%~dp0..\out\YataiDONSimpleStyle" "D:\GitHubRepos\Z-DON\build\bin\Skins\YataiDONSimpleStyle" /MIR /NFL /NDL /NJH /NP
if %ERRORLEVEL% GEQ 8 (echo copy failed & exit /b 1)
echo installed to D:\GitHubRepos\Z-DON\build\bin\Skins\YataiDONSimpleStyle
exit /b 0
