FROM maven:3.9.9-eclipse-temurin-17 AS build
WORKDIR /src
COPY pom.xml .
COPY src ./src
RUN mvn -DskipTests clean package

FROM eclipse-temurin:17-jre
WORKDIR /app

# Install net-tools for netstat
RUN apt-get update && \
    apt-get install -y net-tools && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /src/target/app.jar /app/app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]
