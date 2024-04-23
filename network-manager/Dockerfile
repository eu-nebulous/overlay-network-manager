FROM docker.io/curlimages/curl:8.5.0 AS downloader
ARG RUN_JAVA_VERSION=1.3.5
RUN curl https://repo1.maven.org/maven2/io/fabric8/run-java-sh/${RUN_JAVA_VERSION}/run-java-sh-${RUN_JAVA_VERSION}-sh.sh -o /tmp/run-java.sh

FROM docker.io/maven:3.9.1-eclipse-temurin-20 AS build

WORKDIR /app
COPY src ./src
COPY bootstrap-agent-scripts/wireguard ./wg-bootstrap-agent-scripts
COPY pom.xml ./

RUN mvn clean package -DskipTests

FROM docker.io/eclipse-temurin:20-jre-alpine

ENV USER_ID=1001

RUN mkdir /deployments \
    && chown ${USER_ID} /deployments \
    && chmod "g+rwX" /deployments \
    && chown 1001:root /deployments

COPY --from=downloader /tmp/run-java.sh /deployments/run-java.sh

RUN chown ${USER_ID} /deployments/run-java.sh && chmod 540 /deployments/run-java.sh

# Configure the JAVA_OPTIONS, you can add -XshowSettings:vm to also display the heap size.
ENV JAVA_OPTIONS="-Dquarkus.http.host=0.0.0.0 -Djava.util.logging.manager=org.jboss.logmanager.LogManager"
ENV JAVA_TOOL_OPTIONS="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:8090"
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en'

# Copy the built artifact from the maven image
COPY --from=build /app/target/*-runner.jar /deployments/app.jar

# Copy scripts from build Dockerfile step
COPY --from=build /app/wg-bootstrap-agent-scripts /deployments/wg-bootstrap-agent-scripts

EXPOSE 8080
EXPOSE 8090

USER ${USER_ID}

ENTRYPOINT [ "/deployments/run-java.sh" ]