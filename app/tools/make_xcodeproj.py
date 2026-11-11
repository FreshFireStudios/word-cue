#!/usr/bin/env python3
"""Writes WordCue.xcodeproj/project.pbxproj for both apps.

    python3 tools/make_xcodeproj.py      (run from the app/ folder)

The project uses Xcode 16's folder-synced groups: every file inside WordCue/
belongs to the Word Cue app and every file inside WordCueLab/ belongs to
Word Cue Lab, automatically. Both use the local WordCueKit package.
Only run this again to add a target or change a build setting; adding or
renaming source files never needs it.
"""
MIC = "Word Cue listens to the sermon audio to catch Bible references. Audio is processed on this Mac and is never recorded or sent anywhere."
SPEECH = "Word Cue turns the sermon audio into text on this Mac to find Bible references."
TARGETS = [
    dict(n=1, name="WordCue", product="Word Cue", folder="WordCue", bundle="com.freshfirestudios.wordcue",
         extra={"CODE_SIGN_ENTITLEMENTS": "Config/WordCue.entitlements", "INFOPLIST_FILE": "Config/Info.plist",
                "INFOPLIST_KEY_NSMicrophoneUsageDescription": MIC, "INFOPLIST_KEY_NSSpeechRecognitionUsageDescription": SPEECH,
                "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.productivity"}),
    dict(n=2, name="WordCueLab", product="Word Cue Lab", folder="WordCueLab", bundle="com.freshfirestudios.wordcuelab",
         extra={"INFOPLIST_KEY_NSSpeechRecognitionUsageDescription": "Word Cue Lab turns sermon recordings into text on this Mac to test Bible reference detection.",
                "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.developer-tools"}),
]


def oid(n, kind):
    return "AA%02d%020d" % (n, kind)


def q(v):
    return v if v.replace("_", "").replace(".", "").replace("/", "").isalnum() else '"%s"' % v.replace('"', '\\"')


def settings(t):
    s = {
        "ARCHS": "arm64", "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor", "CODE_SIGN_STYLE": "Automatic",
        "COMBINE_HIDPI_IMAGES": "YES", "CURRENT_PROJECT_VERSION": "1", "ENABLE_APP_SANDBOX": "NO",
        "ENABLE_HARDENED_RUNTIME": "YES", "ENABLE_PREVIEWS": "YES", "GENERATE_INFOPLIST_FILE": "YES",
        "INFOPLIST_KEY_CFBundleDisplayName": t["product"],
        "INFOPLIST_KEY_NSHumanReadableCopyright": "© 2026 Bryson Woods, Fresh Fire Studios. All rights reserved.",
        "MARKETING_VERSION": "0.1.0", "PRODUCT_BUNDLE_IDENTIFIER": t["bundle"], "PRODUCT_MODULE_NAME": t["name"],
        "PRODUCT_NAME": t["product"], "SWIFT_EMIT_LOC_STRINGS": "YES", "SWIFT_VERSION": "5.0",
    }
    s.update(t["extra"])
    lines = ["\t\t\t\t%s = %s;" % (k, q(v)) for k, v in sorted(s.items())]
    lines.append('\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (\n\t\t\t\t\t"$(inherited)",\n\t\t\t\t\t"@executable_path/../Frameworks",\n\t\t\t\t);')
    return "\n".join(sorted(lines))


PROJECT_DEBUG = """ALWAYS_SEARCH_USER_PATHS = NO; CLANG_ENABLE_MODULES = YES; CLANG_ENABLE_OBJC_ARC = YES; COPY_PHASE_STRIP = NO;
DEBUG_INFORMATION_FORMAT = dwarf; ENABLE_STRICT_OBJC_MSGSEND = YES; ENABLE_TESTABILITY = YES; ENABLE_USER_SCRIPT_SANDBOXING = YES;
GCC_OPTIMIZATION_LEVEL = 0; MACOSX_DEPLOYMENT_TARGET = 27.0; ONLY_ACTIVE_ARCH = YES; SDKROOT = macosx;
SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)"; SWIFT_OPTIMIZATION_LEVEL = "-Onone";"""
PROJECT_RELEASE = """ALWAYS_SEARCH_USER_PATHS = NO; CLANG_ENABLE_MODULES = YES; CLANG_ENABLE_OBJC_ARC = YES; COPY_PHASE_STRIP = NO;
DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"; ENABLE_NS_ASSERTIONS = NO; ENABLE_STRICT_OBJC_MSGSEND = YES; ENABLE_USER_SCRIPT_SANDBOXING = YES;
MACOSX_DEPLOYMENT_TARGET = 27.0; SDKROOT = macosx; SWIFT_COMPILATION_MODE = wholemodule;"""


def block(text):
    return "\n".join("\t\t\t\t" + part.strip() + ";" for part in text.replace("\n", " ").split(";") if part.strip())


P = "AA00%020d"
o = []
w = o.append
w("// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {\n\t};\n\tobjectVersion = 77;\n\tobjects = {\n")
for t in TARGETS:
    n = t["n"]
    w('\t\t%s = {isa = PBXBuildFile; productRef = %s; };' % (oid(n, 10), oid(n, 11)))
    w('\t\t%s = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "%s.app"; sourceTree = BUILT_PRODUCTS_DIR; };' % (oid(n, 20), t["product"]))
    w('\t\t%s = {isa = PBXFileSystemSynchronizedRootGroup; path = %s; sourceTree = "<group>"; };' % (oid(n, 30), t["folder"]))
    w('\t\t%s = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (%s, ); runOnlyForDeploymentPostprocessing = 0; };' % (oid(n, 40), oid(n, 10)))
    w('\t\t%s = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };' % oid(n, 41))
    w('\t\t%s = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };' % oid(n, 42))
    w('\t\t%s = {isa = XCSwiftPackageProductDependency; productName = WordCueKit; };' % oid(n, 11))
    w('''\t\t%s = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = %s;
\t\t\tbuildPhases = (%s, %s, %s, );
\t\t\tbuildRules = ();
\t\t\tdependencies = ();
\t\t\tfileSystemSynchronizedGroups = (%s, );
\t\t\tname = %s;
\t\t\tpackageProductDependencies = (%s, );
\t\t\tproductName = %s;
\t\t\tproductReference = %s;
\t\t\tproductType = "com.apple.product-type.application";
\t\t};''' % (oid(n, 60), oid(n, 92), oid(n, 41), oid(n, 40), oid(n, 42), oid(n, 30), t["name"], oid(n, 11), t["name"], oid(n, 20)))
    for cfg, k in (("Debug", 82), ("Release", 83)):
        w('\t\t%s = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {\n%s\n\t\t\t};\n\t\t\tname = %s;\n\t\t};' % (oid(n, k), settings(t), cfg))
    w('\t\t%s = {isa = XCConfigurationList; buildConfigurations = (%s, %s, ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };' % (oid(n, 92), oid(n, 82), oid(n, 83)))
w('\t\t%s = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };' % (P % 21))
w('\t\t%s = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = WordCue.entitlements; sourceTree = "<group>"; };' % (P % 22))
w('\t\t%s = {isa = PBXGroup; children = (%s, %s, ); path = Config; sourceTree = "<group>"; };' % (P % 51, P % 21, P % 22))
w('\t\t%s = {isa = PBXGroup; children = (%s ); name = Products; sourceTree = "<group>"; };' % (P % 52, "".join(oid(t["n"], 20) + ", " for t in TARGETS)))
w('\t\t%s = {isa = PBXGroup; children = (%s%s, %s, ); sourceTree = "<group>"; };' % (P % 50, "".join(oid(t["n"], 30) + ", " for t in TARGETS), P % 51, P % 52))
w('\t\t%s = {isa = XCLocalSwiftPackageReference; relativePath = WordCueKit; };' % (P % 12))
for cfg, k, body in (("Debug", 80, PROJECT_DEBUG), ("Release", 81, PROJECT_RELEASE)):
    w('\t\t%s = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {\n%s\n\t\t\t};\n\t\t\tname = %s;\n\t\t};' % (P % k, block(body), cfg))
w('\t\t%s = {isa = XCConfigurationList; buildConfigurations = (%s, %s, ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };' % (P % 91, P % 80, P % 81))
w('''\t\t%s = {
\t\t\tisa = PBXProject;
\t\t\tattributes = {
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 2700;
\t\t\t\tLastUpgradeCheck = 2700;
\t\t\t};
\t\t\tbuildConfigurationList = %s;
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (en, Base, );
\t\t\tmainGroup = %s;
\t\t\tminimizedProjectReferenceProxies = 1;
\t\t\tpackageReferences = (%s, );
\t\t\tpreferredProjectObjectVersion = 77;
\t\t\tproductRefGroup = %s;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (%s);
\t\t};''' % (P % 70, P % 91, P % 50, P % 12, P % 52, "".join(oid(t["n"], 60) + ", " for t in TARGETS)))
w("\t};\n\trootObject = %s;\n}\n" % (P % 70))
open("WordCue.xcodeproj/project.pbxproj", "w", encoding="utf-8").write("\n".join(o))
print("wrote WordCue.xcodeproj/project.pbxproj with targets:", ", ".join(t["name"] for t in TARGETS))
