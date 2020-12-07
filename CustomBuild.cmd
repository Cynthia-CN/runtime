@ECHO OFF
SETLOCAL EnableDelayedExpansion

REM Validate script environment
IF NOT "%VSINSTALLDIR%" == "" (
    ECHO Build shouldn't be done in a VS Developer prompt
    GOTO :EOF
)

REM Process script arguments
SET BUILD_CORECLR=TRUE
SET BUILD_COREFX=FALSE
SET BUILD_NATIVE_TESTS=FALSE
SET BUILD_CORE_ROOT=TRUE
FOR %%G IN (%*) DO (
    IF "%%G" == "-clr" SET BUILD_CORECLR=FALSE
    IF "%%G" == "fx" SET BUILD_COREFX=TRUE
    IF "%%G" == "ntests" SET BUILD_NATIVE_TESTS=TRUE
    IF "%%G" == "-cr" SET BUILD_CORE_ROOT=FALSE
)

REM Environment configuration
SET RUNTIME_ROOT=D:\runtime

REM Build configuration
SET CORECLR_ARCH=x64
SET CORECLR_CONFIG=Debug
SET COREFX_ARCH=%CORECLR_ARCH%
SET COREFX_CONFIG=Release

ECHO ==========================================
ECHO .NET Core dev inner loop
ECHO    RUNTIME_ROOT=%RUNTIME_ROOT%
ECHO    CORECLR_ARCH=%CORECLR_ARCH%
ECHO    CORECLR_CONFIG=%CORECLR_CONFIG%
ECHO    COREFX_ARCH=%COREFX_ARCH%
ECHO    COREFX_CONFIG=%COREFX_CONFIG%
ECHO ==========================================

REM Validation
IF NOT EXIST %RUNTIME_ROOT% (
    ECHO Invalid RUNTIME_ROOT
    GOTO :EOF
)

SET RUNTIME_SRC=%RUNTIME_ROOT%\src
SET RUNTIME_CORECLR=%RUNTIME_SRC%\coreclr
SET RUNTIME_TESTS=%RUNTIME_SRC%\tests

REM Start timer
SET START_TIME=%TIME%

REM Build CoreCLR
IF NOT "%BUILD_CORECLR%" == "TRUE" GOTO :DONE_CORECLR

PUSHD "%RUNTIME_ROOT%"
CALL build.cmd -subset Clr -configuration %CORECLR_CONFIG%  -arch %CORECLR_ARCH%
POPD

IF NOT !ERRORLEVEL! == 0 (
    ECHO Failed to build CORECLR [!ERRORLEVEL!]
    GOTO :DONE
)
:DONE_CORECLR

REM Build CoreFX
IF NOT "%BUILD_COREFX%" == "TRUE" GOTO :DONE_COREFX

PUSHD "%RUNTIME_ROOT%"
CALL build.cmd -subset Libs -configuration %COREFX_CONFIG% -arch %COREFX_ARCH% -restore -build -runtimeConfiguration %CORECLR_CONFIG%
POPD

IF NOT !ERRORLEVEL! == 0 (
    ECHO Failed to build COREFX [!ERRORLEVEL!]
    GOTO :DONE
)
:DONE_COREFX

REM Build Native tests
IF NOT "%BUILD_NATIVE_TESTS%" == "TRUE" GOTO :DONE_NATIVE_TESTS

PUSHD "%RUNTIME_TESTS%"
CALL build.cmd %CORECLR_ARCH% %CORECLR_CONFIG% skipmanaged
POPD

IF NOT !ERRORLEVEL! == 0 (
    ECHO Failed to build native tests [!ERRORLEVEL!]
    GOTO :DONE
)
:DONE_NATIVE_TESTS

REM Build CORE_ROOT
IF NOT "%BUILD_CORE_ROOT%" == "TRUE" GOTO :DONE_CORE_ROOT

PUSHD "%RUNTIME_TESTS%"
CALL build.cmd %CORECLR_ARCH% %CORECLR_CONFIG% skipnative skipmanaged /p:LibrariesConfiguration=%COREFX_CONFIG%
POPD

IF NOT !ERRORLEVEL! == 0 (
    ECHO Failed to build CORE_ROOT [!ERRORLEVEL!]
    GOTO :DONE
)
:DONE_CORE_ROOT

:DONE

ECHO:
ECHO %~nx0 runtime:
ECHO     Start: %START_TIME%
ECHO       End: %TIME%
