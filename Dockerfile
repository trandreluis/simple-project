# Imagem base com JDK 25 (Temurin)
FROM eclipse-temurin:25-jdk-alpine

WORKDIR /app

COPY target/*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java","-jar","/app/app.jar"]
