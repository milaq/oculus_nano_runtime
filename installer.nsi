!include "MUI2.nsh"

!define PROJECT_NAME "Oculus Nano Runtime"
!define VERSION "1.30"

Name "${PROJECT_NAME}"
OutFile "oculus_nano_runtime_${VERSION}.exe"
Unicode True
RequestExecutionLevel Admin
InstallDir "$PROGRAMFILES64\Oculus"

!define PROJECT_TEMP_DIR "$TEMP\Oculus"

!define MUI_WELCOMEFINISHPAGE_BITMAP "res\logo.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "res\logo.bmp"
!define MUI_ABORTWARNING

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "README.txt"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

!insertmacro MUI_LANGUAGE "English"

Section "" SecUninstallPrevious
  Call UninstallPrevious
SectionEnd

Function UninstallPrevious
  SetDetailsView show
  ReadRegStr $R0 HKLM "Software\Oculus VR, LLC\Oculus\" "Base"
  ${If} $R0 == ""
    Goto Done
  ${EndIf}
  DetailPrint "Removing previous installation..."
  nsExec::Exec "$R0\Uninstall.exe /S _?=$INSTDIR"
  Done:
FunctionEnd

Section "Install"
  SetDetailsView show
  SetOutPath "$INSTDIR"
  CreateDirectory "${PROJECT_TEMP_DIR}"

  DetailPrint "Installing binaries..."
  SetOutPath "$INSTDIR\Manifests"
  File /r "vendor\Manifests\*"
  SetOutPath "$INSTDIR\Support\oculus-diagnostics"
  File /r "vendor\Support\oculus-diagnostics\*"
  SetOutPath "$INSTDIR\Support\oculus-drivers"
  File /r "vendor\Support\oculus-drivers\*"
  SetOutPath "$INSTDIR\Support\oculus-platform-runtime"
  File /r "vendor\Support\oculus-platform-runtime\*"
  SetOutPath "$INSTDIR\Support\oculus-runtime"
  File /r "vendor\Support\oculus-runtime\*"
  SetOutPath "$INSTDIR"

  DetailPrint "Installing prerequisites..."
  File "/oname=${PROJECT_TEMP_DIR}\visual-cpp-2013.exe" "res\prerequisites\visual-cpp-2013.exe"
  File "/oname=${PROJECT_TEMP_DIR}\visual-cpp-2013-x86.exe" "res\prerequisites\visual-cpp-2013-x86.exe"
  File "/oname=${PROJECT_TEMP_DIR}\visual-cpp-2015-update-3.exe" "res\prerequisites\visual-cpp-2015-update-3.exe"
  File "/oname=${PROJECT_TEMP_DIR}\vulkan-runtime-1-0-65-1.exe" "res\prerequisites\vulkan-runtime-1-0-65-1.exe"
  ExecWait "${PROJECT_TEMP_DIR}\visual-cpp-2013.exe /quiet"
  ExecWait "${PROJECT_TEMP_DIR}\visual-cpp-2013-x86.exe /quiet"
  ExecWait "${PROJECT_TEMP_DIR}\visual-cpp-2015-update-3.exe /quiet"
  ExecWait "${PROJECT_TEMP_DIR}\vulkan-runtime-1-0-65-1.exe /S"

  DetailPrint "Setting up registry entries..."
  File "/oname=${PROJECT_TEMP_DIR}\oculus_registry.permissions" "res\oculus_registry.permissions"
  nsExec::Exec 'regini.exe "${PROJECT_TEMP_DIR}\oculus_registry.permissions"'
  Pop $0
  ${If} $0 != 0
    DetailPrint "Error: Failed setting up registry entries ($0)."
    abort
  ${EndIf}
  
  WriteRegStr HKLM "Software\Oculus VR, LLC\Oculus\" "Base" "$INSTDIR"
  WriteRegDWORD HKLM "Software\Oculus VR, LLC\Oculus\" "Active" 1
  WriteRegStr HKLM "Software\Oculus VR, LLC\Oculus\" "InitialInstallerVersion" "1.26.0.0"
  WriteRegStr HKLM "Software\Oculus VR, LLC\Oculus\" "DriverVersion" "1.18.0.426075"
  WriteRegDWORD HKLM "Software\Oculus VR, LLC\Oculus\" "Gestalt" 2

  WriteRegStr HKLM "Software\Oculus VR, LLC\Oculus\Config\" "CoreChannel" "LIVE"
  WriteRegStr HKLM "Software\Oculus VR, LLC\Oculus\Config\" "Migrations" "uwp-app-delete,finish-create-library,enable-uwp,new-gestalt,generate-installation-id,migrate-core-data,no-updates,create-coredata"
  WriteRegStr HKLM "Software\Oculus VR, LLC\Oculus\Config\" "InstalledRedistributables" "1675031999409058,910524935693407,1183534128364060,822786567843179,1824471960899274"
  WriteRegDWORD HKLM "Software\Oculus VR, LLC\Oculus\Config\" "Gestalt" 2

  WriteRegStr HKCU "Software\Oculus VR, LLC\Oculus\Libraries\00000000-0000-0000-0000-000000000000" "fuckFacebook" "true"

  DetailPrint "Setting Oculus environment variables..."
  nsExec::Exec '$sysdir\cmd.exe /c setx /M PATH "%PATH%;$INSTDIR\Support\oculus-runtime"'
  Pop $0
  ${If} $0 != 0
    DetailPrint "Error: Failed setting Oculus environment variables ($0)"
    abort
  ${EndIf}
  nsExec::Exec 'setx /M OculusBase "$INSTDIR"'
  Pop $0
  ${If} $0 != 0
    DetailPrint "Error: Failed setting Oculus environment variables ($0)"
    abort
  ${EndIf}

  DetailPrint "Deploying dummy databases..."
  CreateDirectory "$APPDATA\Oculus\sessions\_oaf\"
  File "/oname=$APPDATA\Oculus\sessions\_oaf\data.sqlite" "res\appdata\sessions\_oaf\data.sqlite"
  CreateDirectory "$APPDATA\Oculus\sessions\000000000000000-0000000000\"
  File "/oname=$APPDATA\Oculus\sessions\000000000000000-0000000000\data.sqlite" "res\appdata\sessions\000000000000000-0000000000\data.sqlite"

  DetailPrint "Installing sensor drivers..."
  ExecWait "$INSTDIR\Support\oculus-drivers\oculus-driver.exe"

  DetailPrint "Installing Oculus service..."
  ExecWait "$INSTDIR\Support\oculus-runtime\OVRServiceLauncher.exe -install -start"

  DetailPrint "Writing uninstall information..."
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PROJECT_NAME}" \
    "DisplayName" "${PROJECT_NAME}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PROJECT_NAME}" \
    "UninstallString" "$\"$INSTDIR\uninstall.exe$\""

  DetailPrint "Cleaning up..."
  RMDir /r "${PROJECT_TEMP_DIR}"
SectionEnd

Section "Uninstall"
  SetDetailsView show

  DetailPrint "Stopping and removing Oculus services..."
  nsExec::Exec 'net stop OVRService'
  nsExec::Exec 'net stop OVRLibraryService'
  nsExec::Exec 'taskkill /f /im OculusConfigUtil.exe'
  nsExec::Exec 'taskkill /f /im OVRServer_x64.exe'
  nsExec::Exec 'taskkill /f /im OVRServiceLauncher.exe'
  nsExec::Exec 'sc delete OVRService'
  nsExec::Exec 'sc delete OVRLibraryService'

  DetailPrint "Removing Oculus environment variables..."
  nsExec::Exec 'setx /M OculusBase ""'

  DetailPrint "Removing Oculus databases..."
  RMDir /r "$APPDATA\Oculus\"

  DetailPrint "Removing binaries..."
  RMDir /r "$INSTDIR\Manifests"
  RMDir /r "$INSTDIR\Support"

  DetailPrint "Removing registry entries..."
  DeleteRegKey HKLM "Software\Oculus VR, LLC"
  DeleteRegKey HKCU "Software\Oculus VR, LLC"

  DetailPrint "Cleaning up..."
  Delete "$INSTDIR\Uninstall.exe"
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PROJECT_NAME}"
  RMDir "$INSTDIR"
SectionEnd
