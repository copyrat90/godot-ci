FROM mcr.microsoft.com/dotnet/sdk:9.0
LABEL author="https://github.com/copyrat90/godot-ci/graphs/contributors"

USER root
SHELL ["/bin/bash", "-c"]
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    git-lfs \
    python3 \
    python-is-python3 \
    python3-openssl \
    unzip \
    wget \
    zip \
    openjdk-17-jdk-headless \
    adb \
    rsync \
    wine64 \
    osslsigncode \
    && rm -rf /var/lib/apt/lists/*

# When in doubt, see the downloads page: https://downloads.tuxfamily.org/godotengine/
ARG GODOT_VERSION="4.3"
ARG LIMBOAI_VERSION="1.3.0"

# Example values: stable, beta3, rc1, dev2, etc.
ARG RELEASE_NAME="stable"

ARG GODOT_TEST_ARGS=""
ARG GODOT_PLATFORM="linux.x86_64"

RUN wget https://github.com/limbonaut/limboai/releases/download/v${LIMBOAI_VERSION}/limboai+v${LIMBOAI_VERSION}.godot-${GODOT_VERSION}.dotnet.editor.${GODOT_PLATFORM}.zip \
    && wget https://github.com/limbonaut/limboai/releases/download/v${LIMBOAI_VERSION}/limboai+v${LIMBOAI_VERSION}.godot-${GODOT_VERSION}.dotnet.export-templates.zip \
    && mkdir -p ~/.cache \
    && mkdir -p ~/.config/godot \
    && mkdir -p ~/.local/share/godot/export_templates/${GODOT_VERSION}.${RELEASE_NAME}.mono \
    && unzip limboai+v${LIMBOAI_VERSION}.godot-${GODOT_VERSION}.dotnet.editor.${GODOT_PLATFORM}.zip \
    && unzip godot-limboai.editor.linux.zip \
    && mv godot.linuxbsd.editor.x86_64.mono /usr/local/bin/godot \
    && mv GodotSharp /usr/local/bin/GodotSharp \
    && unzip limboai+v${LIMBOAI_VERSION}.godot-${GODOT_VERSION}.dotnet.export-templates.zip \
    && mv templates/* ~/.local/share/godot/export_templates/${GODOT_VERSION}.${RELEASE_NAME}.mono \
    && rm -f limboai+v${LIMBOAI_VERSION}.godot-${GODOT_VERSION}.dotnet.export-templates.zip limboai+v${LIMBOAI_VERSION}.godot-${GODOT_VERSION}.dotnet.editor.${GODOT_PLATFORM}.zip godot-limboai.editor.linux.zip README.md

ADD getbutler.sh /opt/butler/getbutler.sh
RUN bash /opt/butler/getbutler.sh
RUN /opt/butler/bin/butler -V

ENV PATH="/opt/butler/bin:${PATH}"

# Download and set up Android SDK to export to Android.
ENV ANDROID_HOME="/usr/lib/android-sdk"
RUN wget https://dl.google.com/android/repository/commandlinetools-linux-7583922_latest.zip \
    && unzip commandlinetools-linux-*_latest.zip -d cmdline-tools \
    && mv cmdline-tools $ANDROID_HOME/ \
    && rm -f commandlinetools-linux-*_latest.zip

ENV PATH="${ANDROID_HOME}/cmdline-tools/cmdline-tools/bin:${PATH}"

RUN yes | sdkmanager --licenses \
    && sdkmanager "platform-tools" "build-tools;33.0.2" "platforms;android-33" "cmdline-tools;latest" "cmake;3.22.1" "ndk;25.2.9519653"

# Add Android keystore and settings.
RUN keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 \
    && mv debug.keystore /root/debug.keystore

RUN godot -v -e --quit --headless ${GODOT_TEST_ARGS}
# Godot editor settings are stored per minor version since 4.3.
# `${GODOT_VERSION:0:3}` transforms a string of the form `x.y.z` into `x.y`, even if it's already `x.y` (until Godot 4.9).
RUN echo '[gd_resource type="EditorSettings" format=3]' > ~/.config/godot/editor_settings-${GODOT_VERSION:0:3}.tres
RUN echo '[resource]' >> ~/.config/godot/editor_settings-${GODOT_VERSION:0:3}.tres
RUN echo 'export/android/java_sdk_path = "/usr/lib/jvm/java-17-openjdk-amd64"' >> ~/.config/godot/editor_settings-${GODOT_VERSION:0:3}.tres
RUN echo 'export/android/android_sdk_path = "/usr/lib/android-sdk"' >> ~/.config/godot/editor_settings-${GODOT_VERSION:0:3}.tres
RUN echo 'export/android/debug_keystore = "/root/debug.keystore"' >> ~/.config/godot/editor_settings-${GODOT_VERSION:0:3}.tres
RUN echo 'export/android/debug_keystore_user = "androiddebugkey"' >> ~/.config/godot/editor_settings-${GODOT_VERSION:0:3}.tres
RUN echo 'export/android/debug_keystore_pass = "android"' >> ~/.config/godot/editor_settings-${GODOT_VERSION:0:3}.tres
RUN echo 'export/android/force_system_user = false' >> ~/.config/godot/editor_settings-${GODOT_VERSION:0:3}.tres
RUN echo 'export/android/timestamping_authority_url = ""' >> ~/.config/godot/editor_settings-${GODOT_VERSION:0:3}.tres
RUN echo 'export/android/shutdown_adb_on_exit = true' >> ~/.config/godot/editor_settings-${GODOT_VERSION:0:3}.tres

# Download and set up rcedit to change Windows executable icons on export.
RUN wget https://github.com/electron/rcedit/releases/download/v2.0.0/rcedit-x64.exe -O /opt/rcedit.exe
RUN echo 'export/windows/rcedit = "/opt/rcedit.exe"' >> ~/.config/godot/editor_settings-${GODOT_VERSION:0:3}.tres
RUN echo 'export/windows/wine = "/usr/bin/wine64-stable"' >> ~/.config/godot/editor_settings-${GODOT_VERSION:0:3}.tres
