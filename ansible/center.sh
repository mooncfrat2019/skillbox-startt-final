export super_user=ubuntu
export center_host=217.16.20.190
export vpn_host=217.16.18.112
export ca_country=RU
export ca_state=Moscow
export ca_locality=Moscow
export ca_organization=NEXUS VPN
export ca_email=zix@vk.com
export ca_ou=IT
export ca_days=3650
export cert_days=365
ansible-playbook -i inventory.yml \
                        --extra-vars  '{
                            "center_host":"'${center_host}'",
                            "vpn_host":"'${vpn_host}'",
                            "super_user":"'${super_user}'",
                            "ca_country":"'${ca_country}'",
                            "ca_state":"'${ca_state}'",
                            "ca_locality":"'${ca_locality}'",
                            "ca_organization":"'${ca_organization}'",
                            "ca_email":"'${ca_email}'",
                            "ca_ou":"'${ca_ou}'",
                            "ca_days":"'${ca_days}'",
                            "cert_days":"'${cert_days}'",
                         }' \
                         deploy_pki.yml --limit ca_servers