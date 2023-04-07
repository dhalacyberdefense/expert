<# 3CX Desktop Uninstaller #>
function getUserGUID ($softwareTitle) {
    try {
        Get-ChildItem "Registry::HKEY_USERS\" -ea 0 | ? { $_.PSIsContainer } | % {
            foreach ($node in ("Software","Software\WOW6432Node")) {
                if (test-path "Registry::$_\$node\Microsoft\Windows\CurrentVersion\Uninstall" -ea 0) {
                    $domainName=(get-itemproperty "Registry::$_\Volatile Environment" -Name USERDOMAIN -ea 0).USERDOMAIN
                    $username=(get-itemproperty "Registry::$_\Volatile Environment" -Name USERNAME -ea 0).USERNAME
                    gci "Registry::$_\$node\Microsoft\Windows\CurrentVersion\Uninstall" | % {Get-ItemProperty $_.PSPath} | ? {$_.DisplayName -match $softwareTitle} | % {
                        $objReg=@{
                            displayName=$_.displayName
                            GUID       =$($_.PSChildName).split('}')[0]+'}'
                            UserSID    =$($_.PSParentPath).split('\')[2]
                            Username   ="$domainName\$username"
                        }
                        return $objReg                
                    }
                }
            }
        }
    } catch {
        #do nothing
    }
}

write-host "3CX Desktop Uninstallation Tool"
write-host "================================"

#Vérification si 3CX est installé
if ((getUserGUID "3CX Desktop").count -eq 0) {
    write-host "- 3CX Desktop was not found on this device. It appears to have been uninstalled."
    write-host "  All is well. Exiting." #and nothing hurt
    exit
}

#Kill les process 3CX
get-process | ? {$_.ProcessName -match '3cx'} | % {
    stop-process -Name $_.ProcessName -Force
}
write-host "- 3CX Processes have been killed."

#Définir dans les tâches planifiées la désinstallation
getUserGUID "3CX Desktop" | % {
    write-host "- Found $($_.DisplayName) installed for user $($_.Username); scheduled removal task."
    schtasks /create /sc hourly /tn "3CX Uninstallation for $($_.Username)" /tr "msiexec /x $($_.GUID) /qn" /st $(([DateTime]::Now.AddMinutes(2)).ToString("HH:mm")) /et $(([DateTime]::Now.AddMinutes(4)).ToString("HH:mm")) /ru "$($_.Username)" /f /z | out-null
}

#Suppression des répertoires de force, pour s'attaquer aux DLL infectées
gci "$env:SystemDrive\Users" | % {
    if (test-path "$($_.FullName)\AppData\Local\Programs\3CXDesktopApp") {
        remove-item "$($_.FullName)\AppData\Local\Programs\3CXDesktopApp" -Force -Recurse
        write-host "- Removed 3CX Desktop App directory for user $($_.Name)."
    }
}

@"
================================
 3CX Desktop a été supprimé, mais il n'a pas encore été désinstallé.
 La menace posée par 3CX Desktop a été neutralisée, mais des traces du logiciel subsistent.
 
 Comme le logiciel insiste pour s'installer au niveau de l'utilisateur individuel, il ne peut être désinstallé que par l'utilisateur individuel.
 désinstaller que par l'utilisateur individuel. Le composant a donc créé des tâches planifiées pour chaque utilisateur sur cet appareil.
 Le composant a donc créé des tâches planifiées pour chaque utilisateur de ce dispositif, à exécuter dans quelques minutes, ce qui achèvera la désinstallation.
 Ce qui reste de 3CX n'est pas considéré comme nuisible ; il est supprimé par souci de rigueur.

 Un raccourci "3CX Desktop" restera sur le bureau pendant quelques minutes jusqu'à ce que cette seconde désinstallation soit effectuée.
 Si vous êtes vigilant, gardez cela à l'esprit : la désinstallation complète de 3CX Desktop peut être confirmée en réexécutant ce composant.
 
 Le répertoire '3CXPhone for Windows' dans $env:ProgramData a été conservé.
 Son contenu n'est pas considéré comme nuisible et peut contenir des données de configuration importantes.
 
 Contactez les experts de Dhala Cyberdéfense https://dhala.fr/ pour obtenir de l'aide. Merci à Seagull et Datto pour le script.
"@
