<#
Author: Luke Hanssen
Created : 23.09.2022
Modified: 29.09.2022
Version: 1.7
Short-Description: A Script vto Deploy Vlans to all Switches maintained
Long-Description: A Script to Deploy Vlans to all network switches which are maintained in path : "C:/Temp/data.txt" when an IP ends with a "|" that means it is currently disabled/ignored.
                   The Script takes longer the more ips are maintained and the more Vlan Ids are taken already.
                   When the Variable $dev is set to true the program outputs all the variables that would have been send to the switch.
#>
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$name = Read-Host -Prompt "Name of the new Vlan "
$name = ($name -replace " ", "-")
$data = Get-Content "C:/Temp/data.txt"
$dev = $false
$notpossible_ips = @()
$path = "./Error_VLANs.txt"
#Überprüfen aller benutzen ids und gibt die nächste freie id wieder 
function getfreeid($ip, $freeid){
    $i = 1
    $used_ids = @()
    $output = C:\Temp\net-snmp5.7.0\bin\snmpwalk.exe -v1 -m "C:/Temp/net-snmp5.7.0/bin/mib/rfc2578.mib"-c public $ip 1.3.6.1.2.1.17.7.1.4.3.1.1
    if($output.Length -eq 0){
   	    write-host "Switch ${ip} unreachable"
        return 0 
    }
    foreach ($item in $output){
        $item = ($item -split '.',34)[33]
        $item = ($item -split '=',2)[0]
        $item = $item -as [int]
        $used_ids +=$item
    }
    while ($i -in $used_ids -or $i -lt $freeid){
    $i += 1
    }
    return $i
}
#Erstellen eines vlans und schreiben von fehlgeschlagenen Erstellungen in ein Array
function createvlan($name,$ip, $tagged, $id){
    $fehler = ""
    $fehler = C:\Temp\net-snmp5.7.0\bin\snmpset.exe -v1 -m "C:/Temp/net-snmp5.7.0/bin/mib/rfc2578.mib" -c "private community key" ${ip} 1.3.6.1.2.1.17.7.1.4.3.1.1.${id} s ${name} 1.3.6.1.2.1.17.7.1.4.3.1.2.${id} x ${tagged} 1.3.6.1.2.1.17.7.1.4.3.1.5.${id} i 4 
    if($fehler -eq $null){
        $global:notpossible_ips += $ip.ToString()
       }
}
#Ziehen der meist benutzen ports eines switches und wieder geben
function gettagged($ip){
    $hexs = @()
    $output = C:\Temp\net-snmp5.7.0\bin\snmpwalk.exe -v1 -m "C:/Temp/net-snmp5.7.0/bin/mib/rfc2578.mib"-c public $ip 1.3.6.1.2.1.17.7.1.4.3.1.2
    foreach($value in $output){
        $value = ($value -split ":",4)[3]
        $hexs += $value
    }
    $group = $hexs | Group-Object -AsHashTable -AsString
    $highest = 0
    $highestvalue = ""
    foreach( $key in $group.Keys){
        if($group[$key].Count -gt $highest){
        $highest = $group[$key].Count
        $highestvalue = $group[$key][0]
        }
    }
    return $highestvalue
}
$freeid = 0
$runs = 0
#Check id if its free for all devices
while($runs -ne 2){
    foreach($ip in $data){
        if(!$ip.EndsWith("|")){
            $id = getfreeid -ip ${ip} -freeid ${freeid}
            if ($id -gt $freeid ){
                $freeid = $id
                $runs = 0
            }
        }
    }
    $runs += 1
}
#create the vlan on each ip
foreach($ip in $data){
    if(!$ip.EndsWith("|")){
        if($ip -eq "192.168.99.6"){
            $tagged = gettagged -ip $ip
            if($dev){
                Write-Host $name
                write-host $ip
                Write-Host $tagged
                write-host $freeid
            }else{
                createvlan -name $name -ip $ip -tagged $tagged -id $freeid
            }
        }
    }
}
#Write data into output file
if($notpossible_ips -ne @()){ 
    echo "Switches auf denen das VLAN nicht eingerichtet werden konnte:" > $path
    foreach($ip in $notpossible_ips){
        echo "`t $ip" >> $path
    }
    echo `n >> $path 
    echo "config terminal" >> $path
    echo " vlan $freeid" >> $path
    echo " name $name" >> $path
    echo " exit" >> $path
}
$stopwatch.Stop()
Write-Host $stopwatch.Elapsed
