function Test-ADPesterFR {
    Describe -Name 'Domain Controller Infrastructure Test' {
        try {
            $AllDomains = (get-adforest -ErrorAction Stop).Domains
        } catch {
            $AllDomains = $null
        }

        It -Name 'Active Directory Forest is available' {
            $AllDomains | Should -Not -BeNullOrEmpty
        }
        if ($AllDomains -eq $null) { return }
        foreach ($Domain in $AllDomains) {
            try {
                $DCS = (Get-ADDomainController -Server $Domain -Filter * -ErrorAction Stop | Select HostName).HostName
            } catch {
                $DCS = $null
            }
            It -Name 'Active Directory Domain is available' {
                $DCS | Should -Not -BeNullOrEmpty
            }
            if ($DCS -eq $null) { return }
            foreach ($DC01 in $DCS) {
                Context -Name "$DC01 Availability" {

                    It -Name "$DC01 Responds to Ping" {
                        $Ping = Test-NetConnection -ComputerName $DC01
                        $Ping.PingSucceeded | Should -Be $true
                    }
                    It -Name "$DC01 Responds on Port 53" {
                        $Port = Test-NetConnection -ComputerName $DC01 -Port 53
                        $Port.TcpTestSucceeded | Should -Be $true
                    }
                    It -Name "$DC01 DNS Service is Running" {
                        $DNSsvc = Get-Service -ComputerName $DC01 -Name 'DNS' -ErrorAction Stop
                        $DNSsvc.Status | Should -BeExactly 'Running'
                    }
                    It -Name "$DC01 ADDS Service is Running" {
                        $NTDSsvc = Get-Service -ComputerName $DC01 -Name 'NTDS' -ErrorAction Stop
                        $NTDSsvc.Status | Should -BeExactly 'Running'
                    }
                    It -Name "$DC01 ADWS Service is Running" {
                        $ADWSsvc = Get-Service -ComputerName $DC01 -Name 'ADWS' -ErrorAction Stop
                        $ADWSsvc.Status | Should -BeExactly 'Running'
                    }
                    It -Name "$DC01 KDC Service is Running" {
                        $KDCsvc = Get-Service -ComputerName $DC01 -Name 'Kdc' -ErrorAction Stop
                        $KDCsvc.Status | Should -BeExactly 'Running'
                    }
                    It -Name "$DC01 Netlogon Service is Running" {
                        $Netlogonsvc = Get-Service -ComputerName $DC01 -Name 'Netlogon' -ErrorAction Stop
                        $Netlogonsvc.Status | Should -BeExactly 'Running'
                    }
                }
                Context -Name "Replication Status" {
                    It -Name "$DC01 Last Replication Result is 0 (Success)" {
                        $RepResult = Get-ADReplicationPartnerMetaData -Target "$DC01" -PartnerType Both -Partition *
                        # using $null because success is 0, and that is considered a null value
                        $RepResult.LastReplicationResult | Should -BeIn $null, 0
                    }
                }
                #room for future tests if needed
            }
            Context 'Replication Link Status' {
                $results = repadmin /showrepl * /csv | ConvertFrom-Csv # Get the results of all replications between all DCs
                $groups = $results | Group-Object -Property 'Site DSA source' # Group the results by the source DC
                foreach ($sourcedsa in $groups) {
                    # Create a context for each source DC
                    Context "Site DSA source = $($sourcedsa.Name)" {
                        $targets = $sourcedsa.Group # Assign the value of the groupings to another var since .Group doesn't implement IComparable
                        $targetdsa = $targets | Group-Object -Property 'Site DSA de destination' # Now group within this source DC by the destination DC (pulling naming contexts per source and destination together)
                        foreach ($target in $targetdsa ) {
                            # Create a context for each destination DSA
                            Context "Target DSA = $($target.Name)" {
                                foreach ($entry in $target.Group) {
                                    # List out the results and check each naming context for failures
                                    It "$($entry.'Contexte de nom') - should have zero replication failures" {
                                        $entry."Nombre d'échecs" | Should Be 0
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}