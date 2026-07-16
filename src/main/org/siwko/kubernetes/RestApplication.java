package org.siwko.kubernetes;

import jakarta.ws.rs.ApplicationPath;
import jakarta.ws.rs.core.Application;

@ApplicationPath("/api") // Map your endpoints (e.g. http://localhost:8080/api/)
public class RestApplication extends Application {
}