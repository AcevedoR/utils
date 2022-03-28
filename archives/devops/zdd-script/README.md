#ZDD script

## Usage
- requires Python3.7
- `python3.7 -m pip install -r requirements.txt`
- `python3.7 deploy_an_application.py <environment> <application_name> <desired_instances_number>`
- `--help for options `

you may want to use sudo since it launches an ansible script who needs it

## Warning
If your input ` --waiting_time ` is inferior to 90 (seconds), this is not ZDD anymore !

Because we have to wait for Eureka server (30) + Eureka Client (30) + Ribbon load balancer (30) caches


## Error case
When there was an error, there will probably be multiple unwanted instances up for an env,
you can try to clean the mess with : 
- `python3.7 remove_down_instances_from_eureka.py <environment>`


## Documentation
- https://www.credera.com/blog/technology-solutions/zero-downtime-rolling-deployments-netflixs-eureka-zuul/
- https://stackoverflow.com/questions/30596484/python-asyncio-context