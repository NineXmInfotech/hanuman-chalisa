"""Patch the generated Android project for background audio and reminders.

Run in CI right after `flutter create`.
"""
import glob
import re

MANIFEST = 'android/app/src/main/AndroidManifest.xml'
m = open(MANIFEST, encoding='utf-8').read()

m = m.replace('android:label="hanumanchalisa"', 'android:label="Hanuman Chalisa"')

permissions = [
    'android.permission.WAKE_LOCK',
    'android.permission.FOREGROUND_SERVICE',
    'android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.RECEIVE_BOOT_COMPLETED',
    'android.permission.VIBRATE',
]
perm_xml = ''.join(f'    <uses-permission android:name="{p}" />\n' for p in permissions)
m = m.replace('<application', perm_xml + '    <application', 1)

components = '''
        <meta-data android:name="io.flutter.embedding.android.EnableImpeller" android:value="false" />
        <service android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver>
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
            </intent-filter>
        </receiver>
'''
m = re.sub(r'(<application[^>]*>)', lambda x: x.group(1) + components, m, count=1)
open(MANIFEST, 'w', encoding='utf-8').write(m)

# MainActivity must extend AudioServiceActivity for background playback.
for path in glob.glob('android/app/src/main/kotlin/**/MainActivity.kt', recursive=True):
    k = open(path, encoding='utf-8').read()
    k = k.replace('import io.flutter.embedding.android.FlutterActivity',
                  'import com.ryanheise.audioservice.AudioServiceActivity')
    k = re.sub(r':\s*FlutterActivity\(\)', ': AudioServiceActivity()', k)
    open(path, 'w', encoding='utf-8').write(k)
    print('patched', path)

# Core library desugaring (needed by flutter_local_notifications).
kts = glob.glob('android/app/build.gradle.kts')
groovy = glob.glob('android/app/build.gradle')
if kts:
    g = open(kts[0], encoding='utf-8').read()
    g = g.replace('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true', 1)
    g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    open(kts[0], 'w', encoding='utf-8').write(g)
    print('patched', kts[0])
elif groovy:
    g = open(groovy[0], encoding='utf-8').read()
    g = g.replace('compileOptions {', 'compileOptions {\n        coreLibraryDesugaringEnabled true', 1)
    g += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    open(groovy[0], 'w', encoding='utf-8').write(g)
    print('patched', groovy[0])

print(open(MANIFEST).read())
