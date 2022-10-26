FROM openjdk:11
ARG JAR_FILE=build/libs/*.jar
COPY ${JAR_FILE} app.jar
ENV SPRING_PROFILES_ACTIVE=dev1
ENTRYPOINT ["java","-Dspring.profiles.active=dev1","-jar","/app.jar"]