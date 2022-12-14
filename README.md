Create an environment with Terraform and configure ELK stack + Kafka + Nginx + Beats with Ansible playbooks.

Here are 3 options to run the project:<br />
<br />
a) All environment is AWS oriented, it is necessary to have a domain in Route53 and assigned to this domain certificate in Certificate Manager service. In this case, we use folder terraform_ALB_Route53_managed for the creation of infrastructure with Terraform. Terraform creates: Application Load Balancer, Load Balancer target group, Load Balancer listeners, A record related to DNS subdomain, network security groups, ELK stack and worker EC2 instances.<br />
<br />
b) We have a domain from another domain provier (f.e. GoDaddy in my case) and secure HTTPS connection with a Let's Encrypt SSL certificate. In this case, we use folder terraform_EC2_managed for the creation of infrastructure with Terraform. Terraform creates network security groups, ELK stack and worker EC2 instances. We need to create (or change) manually A record in our domain provider configuration for an assignation with the public IP address of the ELK stack instance.<br />
<br />
c) We don't have any domain and secure HTTPS connection with an OpenSSL certificate. In this case, we use folder terraform_EC2_managed for the creation of infrastructure with Terraform. Terraform creates network security groups, ELK stack and worker EC2 instances.<br />

![ELK Stack + Beats + Kafka + NGINX + Grafana](images/ELK_stack_diagram.png)

1.  clone the repo<br />
```git clone git@github.com:Andr1500/ELK_NGINX_Kafka_Grafana.git```

2.  go to Terraform folder<br />
set AWS credentials, credentials can be exported as environment variables:<br />
```export AWS_SECRET_ACCESS_KEY="SECRET_KEY"```<br />
```export AWS_ACCESS_KEY_ID="ACCES_KEY"```<br />
run ```terraform init```<br />
if everything is ok, run ```terraform plan``` and ```terraform apply```.<br /> Infrastructure in AWS and inventory file hosts.txt in ELK_stack directory will be created.

3. All Ansible variables are in ELK_stack/group_vars/all.yml file. Add ```server_domain``` and ```certbot_mail_address``` variables if you need to assign the Let's Encrypt SSL certificate to the NGINX server and use the domain name. Here is in use domain from GoDaddy and it's necessary to create (or change) A record for forwarding traffic to the created server. In case you don't have any domain name you can use a self-assigned OpenSSL certificate. Add ```server_domain``` variable if you use the domain from Route53.<br />
Add ```kafka_host``` variable (IP address of ELK stack EC2 instance).

4. Go to ELK_stack folder and run:<br />
a) for the environment with Certificate Manager SSL certificate:<br />
for installation and configuration of ELK stack:<br />
```ansible-playbook -i hosts.txt -l elk_stack ELK_stack_cermanager.yml```<br />
for installation and configuration workers:<br />
```ansible-playbook -i hosts.txt -l worker ELK_beats.yml```<br />
b) for the environment with the Let's Encrypt SSL certificate:<br />
for installation and configuration of ELK stack:<br />
```ansible-playbook -i hosts.txt -l elk_stack ELK_stack_letsencrypt.yml```<br />
for installation and configuration workers:<br />
```ansible-playbook -i hosts.txt -l worker ELK_beats.yml```<br />
Next, go to your hosting provider and add A record.<br />
![Godaddy A record](images/godaddy.png)<br />
c) for the environment with OpenSSL SSL certificate:<br />
for installation and configuration of ELK stack:<br />
```ansible-playbook -i hosts.txt -l elk_stack ELK_stack_openssl.yml```<br />
for installation and configuration workers:<br />
```ansible-playbook -i hosts.txt -l worker ELK_beats.yml```<br />

5. Copy the public IP address of the ELK stack instance, go to any WEB browser and paste it into the search bar. It will automatically redirect to HTTPS and you can see information that the page is not secure if you installed Nginx with an OpenSSL certificate. Ignore it and go to the web page. If you configured "ELK stack" with Let's Encrypt or Certificate Manager certificate it will be automatically redirected to the domain name.

6. Choose "Kibana service" and login in with elastic credentials. Next choose "Kibana/Index Patterns" -> Create index pattern. Created patterns will be available in the "Discover" options.

7. Choose "Grafana service" and login in with Grafana admin_user and Grafana admin_pasword credentials. Next, add the source of the data: Data Sources -> Elaticsearch.

![Elasticsearch as a datasource](images/grafana_elastic_source1.png)
![Elasticsearch as a datasource](images/grafana_elastic_source2.png)

8. Add new dashboard: Dashboards -> New Dashboard -> Add a new panel -> Apply -> Save Dashboard -> Save.

![Grafana dashboard](images/grafana_dashboard.png)
