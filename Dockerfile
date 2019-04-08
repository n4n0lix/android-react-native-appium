# Base-image: React-Native Android App
FROM openjdk:8-slim

# set default build arguments
ARG SDK_VERSION=sdk-tools-linux-4333796.zip
ARG ANDROID_BUILD_VERSION=28
ARG ANDROID_EMULATOR_IMAGE=system-images;android-25;google_apis;armeabi-v7a
ARG ANDROID_EMULATOR_API=25
ARG ANDROID_TOOLS_VERSION=28.0.3
ARG BUCK_VERSION=2019.01.10.01
ARG NDK_VERSION=17c
ARG WATCHMAN_VERSION=4.9.0

# set default environment variables
ENV ADB_INSTALL_TIMEOUT=10
ENV PATH=${PATH}:/opt/buck/bin/
ENV ANDROID_HOME=/opt/android
ENV ANDROID_SDK_HOME=${ANDROID_HOME}
ENV PATH=${PATH}:${ANDROID_HOME}/emulator:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools
ENV ANDROID_NDK=/opt/ndk/android-ndk-r$NDK_VERSION
ENV ANDROID_NDK_HOME=/opt/ndk/android-ndk-r$NDK_VERSION
ENV PATH=${PATH}:${ANDROID_NDK}

# System Dependencies
#--------------------
RUN apt-get update -qq && apt-get install -qq -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        curl \
        build-essential \
        file \
        git \
        gnupg2 \
        openjdk-8-jre \
        python \
        tzdata \
        unzip \
        gnupg \
        zip \
    && rm -rf /var/lib/apt/lists/*;

# NodeJs & Yarn
#--------------------
RUN echo "deb https://deb.nodesource.com/node_10.x stretch main" > /etc/apt/sources.list.d/nodesource.list \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list \
    && curl -sS https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && apt-get update -qq \
    && apt-get install -qq -y --no-install-recommends nodejs yarn \
    && rm -rf /var/lib/apt/lists/*

# download and unpack NDK
RUN curl -sS https://dl.google.com/android/repository/android-ndk-r$NDK_VERSION-linux-x86_64.zip -o /tmp/ndk.zip \
    && mkdir /opt/ndk \
    && unzip -q -d /opt/ndk /tmp/ndk.zip \
    && rm /tmp/ndk.zip

# download and install buck using debian package
RUN curl -sS -L https://github.com/facebook/buck/releases/download/v${BUCK_VERSION}/buck.${BUCK_VERSION}_all.deb -o /tmp/buck.deb \
    && dpkg -i /tmp/buck.deb \
    && rm /tmp/buck.deb

# Full reference at https://dl.google.com/android/repository/repository2-1.xml
# download and unpack android
RUN curl -sS https://dl.google.com/android/repository/${SDK_VERSION} -o /tmp/sdk.zip \
    && mkdir /opt/android \
    && unzip -q -d /opt/android /tmp/sdk.zip \
    && rm /tmp/sdk.zip

# React-Native
ADD 60-max-user-watches.conf /etc/sysctl.d/60-max-user-watches.conf


# Android SDK tools
#--------------------
RUN cd ~ && mkdir ~/.android && echo '### User Sources for Android SDK Manager' > ~/.android/repositories.cfg \
    && yes | sdkmanager --licenses && sdkmanager --update \
    && yes | sdkmanager "platform-tools" \
        "emulator" \
        "platforms;android-$ANDROID_BUILD_VERSION" \
        "build-tools;$ANDROID_TOOLS_VERSION" \
        "add-ons;addon-google_apis-google-23" \
        #"system-images;android-19;google_apis;armeabi-v7a" \
"extras;android;m2repository"

# Android Emulator
#--------------------
RUN sdkmanager "platform-tools" "platforms;android-$ANDROID_EMULATOR_API" "emulator"
RUN sdkmanager "$ANDROID_EMULATOR_IMAGE"
RUN echo no | avdmanager create avd -n automationTestImage -k "$ANDROID_EMULATOR_IMAGE"

# Appium
#--------------------
RUN apt-get -qqy update && \
    apt-get -qqy --no-install-recommends install \
        libqt5webkit5 \
        libgconf-2-4 \
        salt-minion \
        xvfb \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g appium@${APPIUM_VERSION} --unsafe-perm=true --allow-root && \
    exit 0 && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    apt-get clean


# Appium Port: 4723
EXPOSE 4723

# Appium & Selenium Grid scripts
COPY entry_point.sh \
     generate_config.sh \
     wait_for_emulator.sh \
     kill_emulators.sh \
     /root/

RUN chmod +x /root/entry_point.sh && \
    chmod +x /root/generate_config.sh && \
    chmod +x /root/wait_for_emulator.sh && \
    chmod +x /root/kill_emulators.sh

# Run xvfb and appium server
CMD /root/entry_point.sh
