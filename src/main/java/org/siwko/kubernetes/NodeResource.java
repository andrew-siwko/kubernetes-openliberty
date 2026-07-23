package org.siwko.kubernetes;

import io.kubernetes.client.openapi.ApiClient;
import io.kubernetes.client.openapi.Configuration;
import io.kubernetes.client.openapi.apis.CoreV1Api;
import io.kubernetes.client.openapi.models.V1Node;
import io.kubernetes.client.openapi.models.V1NodeCondition;
import io.kubernetes.client.openapi.models.V1NodeList;
import io.kubernetes.client.util.Config;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import java.io.IOException;

@Path("/")
public class NodeResource {

    @GET
    @Produces(MediaType.TEXT_PLAIN)
    public String getNodes() {
        StringBuilder response = new StringBuilder();
        response.append("Hello! Your Java app is running inside Kubernetes on Open Liberty!\n");

        String currentNode = System.getenv("NODE_NAME");
        response.append("Running on node: ").append(currentNode != null ? currentNode : "unknown").append("\n");

        try {
            // Automatically falls back to in-cluster config when in a pod
            ApiClient client = Config.defaultClient();
            Configuration.setDefaultApiClient(client);

            CoreV1Api api = new CoreV1Api();
            V1NodeList nodeList = api.listNode().execute();

            for (V1Node node : nodeList.getItems()) {
                String name = node.getMetadata().getName();
                String status = "Not Ready";

                if (node.getStatus() != null && node.getStatus().getConditions() != null) {
                    for (V1NodeCondition condition : node.getStatus().getConditions()) {
                        if ("Ready".equals(condition.getType()) && "True".equals(condition.getStatus())) {
                            status = "Ready";
                            break;
                        }
                    }
                }
                response.append(String.format("('%s', '%s')\n", name, status));
            }

        } catch (IOException e) {
            response.append("Error initializing K8s Client: ").append(e.getMessage()).append("\n");
        } catch (Exception e) {
            response.append("Error fetching nodes: ").append(e.getMessage()).append("\n");
        }

        return response.toString();
    }
}