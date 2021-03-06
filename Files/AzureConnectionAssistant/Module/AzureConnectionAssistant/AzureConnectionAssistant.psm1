function Test-Session ()
{
<#
.SYNOPSIS
Function to validate a connection to an Azure RM Subscription.

.DESCRIPTION
This function initiates a check to see if you are have a current Azure Login session, if it
finds you don't, it prompts you to select credentials saved in the Registry.

.EXAMPLE
	PS C:\> Test-Session
	No session found or No local credentials stored.
	Please select from the following
	1: MyAzureCreds
	2: To enter credentials manually (Needed for any Federated credentials)
	Select: : 1

	Environment           : AzureCloud
	Account               : scott@examplenotreal.com
	TenantId              : 123e7e65-2654-43c1-b123-caf99f844a69
	SubscriptionId        : 5095e43d-2fee-4c98-bd73-b7c5c7e01012
	SubscriptionName      : Pay-As-You-Go
	CurrentStorageAccount :

	PS C:\>

This example demonstrates running the function in a fresh PowerShell session, with no current
connection. The Function lists the saved credentials that are stored locally and prompts for a
selection as to which credential to use. Then proceeds to make a connection to AzureRM with
the selected credentials.

.NOTES
Created by: Scott Thomas - scott@deathbyvegemite.com
Copyright (c) 2017. All rights reserved.	

THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE RISK
OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.
#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	Param()
	trap{Write-Host -f Red "$($_.Exception.Message)"; return $false}
	$sesh = Get-AzureRmContext -ErrorAction SilentlyContinue
	if ($Sesh.Environment -like $null)
	{
		Write-Host -f Yellow "No session found or no local credentials stored."
		New-AzureRMLogin
	}
	else
	{
		if($pscmdlet.ShouldProcess("Test-Session is positive","Return"))
		{
			return $sesh
		}
	}
}


function New-AzureRMLogin
{
<#
.SYNOPSIS
Function to connect to an AzureRM Subscription.

.DESCRIPTION
This function is used by Test-Session to connect to Azure using credentials saved in the Registry of the current user.

.PARAMETER ConnectWithDefault
This switch will force the use of the first saved credential.

.EXAMPLE
PS C:\> New-AzureRMLogin
Please select from the following
1: MyAzureCreds
2: To enter credentials manually (Needed for any Federated credentials)
Select: : 1

Environment           : AzureCloud
Account               : scott@examplenotreal.com
TenantId              : 123e7e65-2654-43c1-b123-caf99f844a69
SubscriptionId        : 5095e43d-2fee-4c98-bd73-b7c5c7e01012
SubscriptionName      : Pay-As-You-Go
CurrentStorageAccount :
	
PS C:\>

This example demonstrates connecting to an Azure RM Subscription, after being prompted and selecting the first saved credentials.

.NOTES
Created by: Scott Thomas - scott@deathbyvegemite.com
Copyright (c) 2017. All rights reserved.	

THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE RISK
OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.
#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	Param
	(
		[Parameter(Mandatory = $false, ValueFromPipeline = $false)][Switch]$ConnectWithDefault
	)
	trap { Write-Host -f Red "$($_.Exception.Message)"; return $false }
	if ((Test-Path -Path HKCU:\System\CurrentControlSet\SecCreds) -eq $false){return $false}
	if ($ConnectWithDefault)
	{
		$Credname = (Show-SavedCreds)[0].Name
		$creds = Get-SavedCreds $Credname
	}
	else
	{
		Write-Host "Please select from the following"
		$i = 1; Foreach ($Name in (Show-SavedCreds | select Name)) { Write-Host "$i`: $($name.name)"; $i++ }
		Write-Host "$i`: To enter credentials manually (Needed for any Federated credentials)"
		$promptvalue = Read-Host -Prompt "Select: "
		if ($promptvalue -eq $i)
		{
			if($pscmdlet.ShouldProcess("Azure - with Federated account"))
			{
				$return = Login-AzureRmAccount
				return $return
			}
		}
		else
		{ 
			$CredToConnectTo = (Show-SavedCreds)[($promptvalue - 1)]
			$Credname = $CredToConnectTo.name
			$creds = Get-SavedCreds $($CredToConnectTo.name)
		}
	}	
	if($pscmdlet.ShouldProcess("Azure - with $Credname saved credentials"))
	{
		$return = Login-AzureRmAccount -Credential $creds
		return $return
	}
}


function New-SavedCreds
{
<#
.SYNOPSIS
Function to save credentials to the HKCU.

.DESCRIPTION
This function will save an encrypted credential to the HKCU hive of the current users' context.

.PARAMETER CredName
This is the name used to save the credentials under in the registry.

.PARAMETER Creds
This is an object containing a PSCredential.

.EXAMPLE
PS C:\> $creds = Get-Credential scott@examplenotreal.com
PS C:\> New-SavedCreds -CredName MyAzureCreds -Creds $creds
True
PS C:\>

This example demonstrates saving a set of credentuals to a variable, then adding that PSCredential to the registry.

.NOTES
Created by: Scott Thomas - scott@deathbyvegemite.com
Copyright (c) 2017. All rights reserved.	

THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE RISK
OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.
#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	Param
	(
		[Parameter(Mandatory = $true, ValueFromPipeline = $false)][String]$CredName,
		[Parameter(Mandatory = $true, ValueFromPipeline = $false)][System.Management.Automation.PSCredential]$Creds
	)
	trap { Write-Host -f Red "$($_.Exception.Message)"; return $false }
	if ((Test-Path -Path HKCU:\System\CurrentControlSet\SecCreds) -eq $false)
	{
		$null = New-Item -Path HKCU:\System\CurrentControlSet\SecCreds
	}
	$null = New-Item -Path HKCU:\System\CurrentControlSet\SecCreds\$CredName
	if($pscmdlet.ShouldProcess("ItemProperty: HKCU:\System\CurrentControlSet\SecCreds\$CredName\UserName","New-ItemProperty"))
	{
		$null = New-ItemProperty -Path HKCU:\System\CurrentControlSet\SecCreds\$CredName -Name UserName -Value $creds.UserName
	}
	$password = $creds.Password | ConvertFrom-SecureString
	if($pscmdlet.ShouldProcess("ItemProperty: HKCU:\System\CurrentControlSet\SecCreds\$CredName\Password","New-ItemProperty"))
	{
		$null = New-ItemProperty -Path HKCU:\System\CurrentControlSet\SecCreds\$CredName -Name Password -Value $password
	}
	if ((Test-Path -Path HKCU:\System\CurrentControlSet\SecCreds\$CredName) -eq $true)
	{
		return $true
	}
	return $false
}


function Get-SavedCreds
{
<#
.SYNOPSIS
Function to save retrieve saved credentials.

.DESCRIPTION
This function will retrieve a set of credentials that are stored in the local users registry.

.PARAMETER CredName
This is the name of the credential to retrieve from the registry.

.EXAMPLE
PS C:\> $creds = Get-SavedCreds MyAzureCreds
PS C:\> $creds
UserName                                Password
--------                                --------
scott@examplenotreal.com System.Security.SecureString

PS C:\>

This example demonstrates getting a credential from the registry and saving it to a variable.

.NOTES
Created by: Scott Thomas - scott@deathbyvegemite.com
Copyright (c) 2017. All rights reserved.	

THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE RISK
OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.
#>
	[CmdletBinding(SupportsShouldProcess = $false)]
	Param
	(
		[Parameter(Mandatory = $true, ValueFromPipeline = $false)][String]$CredName
	)
	trap { Write-Host -f Red "$($_.Exception.Message)"; return $false }
	$test = Test-Path -Path HKCU:\System\CurrentControlSet\SecCreds\$CredName
	if ($test)
	{
		$userName = (Get-ItemProperty -Path HKCU:\System\CurrentControlSet\SecCreds\$CredName -Name UserName).UserName
		$password = (Get-ItemProperty -Path HKCU:\System\CurrentControlSet\SecCreds\$CredName -Name Password).password | ConvertTo-SecureString
		$creds = New-Object System.Management.Automation.PSCredential $userName, $password
		return $creds
	}
	else
	{
		Write-Host -f Red "Credential $($CredName) not found on machine."
		return $false
	}
	return $true
}


function Update-SavedCreds
{
<#
.SYNOPSIS
Function to update a saved credentials.

.DESCRIPTION
This function allows for the updating of an exisitng saved credential.

.PARAMETER CredName
This is the name of the credential to be updated.

.PARAMETER Creds
This is an object containing a new PSCredential.

.EXAMPLE
PS C:\> $creds = Get-Credential scott@examplenotreal.com
PS C:\> Update-SavedCreds -CredName MyAzureCreds -Creds $creds
True
PS C:\>

This example demonstrates updadting a saved credential to new values.

.NOTES
Created by: Scott Thomas - scott@deathbyvegemite.com
Copyright (c) 2017. All rights reserved.	

THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE RISK
OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.
#>
	[CmdletBinding(SupportsShouldProcess = $false)]
	Param
	(
		[Parameter(Mandatory = $true, ValueFromPipeline = $false)][String]$CredName,
		[Parameter(Mandatory = $true, ValueFromPipeline = $false)][System.Management.Automation.PSCredential]$Creds
	)
	trap { Write-Host -f Red "$($_.Exception.Message)"; return $false }
	$test = Test-Path -Path HKCU:\System\CurrentControlSet\SecCreds\$CredName
	if ($test)
	{
		if ($creds)
		{
			$password = $creds.Password | ConvertFrom-SecureString
			Set-ItemProperty -Path HKCU:\System\CurrentControlSet\SecCreds\$CredName -Name Password -Value $password
		}
	}
	else
	{
		Write-Host -f Red "Credential $($CredName) not found on machine."
		return $false
	}
	return $true
}


function Show-SavedCreds
{
<#
.SYNOPSIS
Function to show all saved credentials.

.DESCRIPTION
This function will retrieve allcredentials that are stored in the local users registry and display them on screen.

.PARAMETER ShowPasswords
This switch will allow for the credentials to be decrypted and displayed on screen.

.EXAMPLE
PS C:\> Show-SavedCreds -ShowPasswords

Name			UserName					Password
----			--------					--------
MyAzureCreds	scott@examplenotreal.com	P@s$W0rd!

PS C:\>

This example demonstrates listing all credential from the registry and displaying passwords.

.NOTES
Created by: Scott Thomas - scott@deathbyvegemite.com
Copyright (c) 2017. All rights reserved.	

THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE RISK
OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.
#>
	[CmdletBinding(SupportsShouldProcess = $false)]
	Param
	(
		[Parameter(Mandatory = $false, ValueFromPipeline = $false)][Switch]$ShowPasswords = $false
	)
	trap { Write-Host -f Red "$($_.Exception.Message)"; return $false }
	$tmpContent = @()
	$objReturn = @()
	$tmpContent = Get-ChildItem HKCU:\System\CurrentControlSet\SecCreds\
	foreach ($C in $tmpContent)
	{
		$tmp = $C.name.split("\")[-1]
		If ($ShowPasswords)
		{
			$password = $C.GetValue("Password") | ConvertTo-SecureString
			[String]$stringValue = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
		}
		else
		{
			$stringValue = "**********"
		}
		$objTemp = New-Object -TypeName PSobject
		$objTemp | Add-Member -MemberType NoteProperty -Name Name $tmp
		$objTemp | Add-Member -MemberType NoteProperty -Name UserName $C.GetValue("UserName")
		$objTemp | Add-Member -MemberType NoteProperty -Name Password $stringValue
		
		$objReturn += $objTemp
	}
	return $objReturn
}


function Remove-SavedCreds
{
<#
.SYNOPSIS
Function to remove a saved credential.

.DESCRIPTION
This function will remove a credentail that has been saved in the local users registry.

.PARAMETER CredName
This is the name of the credential to retrieve from the registry.

.EXAMPLE
PS C:\> Remove-SavedCreds -CredName MyAzureCreds

Confirm
Are you sure you want to perform this action?
Performing the operation "Remove-SavedCreds" on target "Are you sure?".
[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "Y"): Y
MyAzureCreds has been removed
True
PS C:\>
	
.NOTES
Created by: Scott Thomas - scott@deathbyvegemite.com
Copyright (c) 2017. All rights reserved.	

THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE RISK
OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.
#>
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
	Param
	(
		[Parameter(Mandatory = $true, ValueFromPipeline = $false)][String]$CredName
	)
	trap{Write-Host -f Red "$($_.Exception.Message)"; return $false}
	if ((Test-Path -Path HKCU:\System\CurrentControlSet\SecCreds\$CredName) -eq $false)
	{
		Write-Host -f Red "Credential name not found"
		return $false
	}

	if ($PSCmdlet.ShouldProcess("Are you sure?"))
	{
		$Error.Clear()
		$toremove = Remove-Item -Path HKCU:\System\CurrentControlSet\SecCreds\$CredName -ErrorAction SilentlyContinue
		If ($Error.Count -eq 0)
		{
			Write-Host -f Yellow "$CredName has been removed"
			return $true
		}
	}
	Write-Host -f Red "Credentials were not able to be removed"
	return $false
}
