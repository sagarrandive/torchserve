# gpu-torchserve

This repo contains an example of a torchserve app that uses stable diffusion XL to generate images from a text prompt.
The image generated is returned back to the caller in a base64 encoded string and can be uploaded to GCS after updating the environment variables PROJECT_ID and BUCKET_NAME in the Dockerfile.

The skelethon comes from this example https://github.com/pytorch/serve/tree/master/examples/diffusers.

## Driver version notice

Cloud Run takes care of the driver version management, meaning that when the container starts the Nvidia driver has been already installed.
We are currently shipping the version `535.129.03 with CUDA 12.2`.

### Backward compatibility

If you plan to use a CUDA version before 12.1 you will need to update the LD_LIBRARY_PATH of your container as: `ENV LD_LIBRARY_PATH /usr/local/nvidia/lib64:${LD_LIBRARY_PATH}`. This is because there is where `libcuda.so` is installed. 

### Forward compatibility

It's possible to bring into the container a newer libcuda.so to access new features that are not currently available in the current Cloud Run driver. More info at https://docs.nvidia.com/deploy/cuda-compatibility/index.html#forward-compatibility-title.

### Driver update

We are going to periodically update the driver under the hood. We leverage the Nvidia binary compatibility guarantees to ensure that the driver update does not disrupt an already deployed application.

## Build

```
PROJECT_ID=<project id>
REPOSITORY=<artifact-registry-repo>
gcloud builds submit --tag us-central1-docker.pkg.dev/$PROJECT_ID/$REPOSITORY/gpu-torchserve
```

## Deploy

### Direct VPC networking

We are going to use the VPC network `default`.

### Cloud NAT

Cloud NAT allows you to have higher bandwidth to access the internet and download the model from HuggingFace, thereby significantly speeding up the deployment times. To create a cloud nat instance via the gcloud cli do:
```
NETWORK_NAME=default

gcloud compute routers create nat-router --network $NETWORK_NAME --region us-central1
gcloud compute routers nats create vm-nat --router=nat-router --region=us-central1 --auto-allocate-nat-external-ips --nat-all-subnet-ip-ranges
```

### Service deployment

```
PROJECT_ID=<project id>
SERVICE_NAME=<service name>
IMAGE=<image url>

gcloud alpha run deploy $SERVICE_NAME --image=$IMAGE --cpu=8 --memory=32Gi --gpu=1 --port=8080 --no-cpu-throttling  --gpu-type=nvidia-l4 --region us-central1 --project $PROJECT_ID --execution-environment=gen2 --max-instances 1 --network $NETWORK_NAME --vpc-egress all-traffic
```

## Query

`URL=<from the deploy command>`

Note if the service does not allow unauthenticated calls you can use the proxy with: `gcloud beta run services proxy $SERVICE_NAME --region us-central1 --port 8080`
In that case the `URL=http://localhost:8080`. Alternatively, you can add `-H "Authorization: Bearer $(gcloud auth print-identity-token)"` to the curl command.

The response is a base64 encoded string of the generated picture so you can query and visualize it with the following bash command:

```
PROMPT_TEXT="freshly made hot floral tea in glass kettle on the table, angled shot, midday warm, Nikon D850 105mm, close-up"
time curl $URL/predictions/stable_diffusion -d "data=$PROMPT_TEXT" | base64 --decode > image.jpg
```
