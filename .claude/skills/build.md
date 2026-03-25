---
name: build
description: Build the project using Gradle/KickAssembler
user_invocable: true
---

Run the Gradle build to assemble all .asm files. Use the Bash tool to execute:

```
./gradlew build
```

If the build fails with an error mentioning "JAVA_HOME is not set" or "no 'java' command could be found", then source Java 17 first and retry:

```
java17 && ./gradlew build
```

Report the build result to the user: which .prg files were produced, or what errors occurred.
