# Builds only the Caelestia.Blobs QML module out of caelestia-dots/shell
# (GPL-3.0): the SDF "blob" shapes that let rise's panels melt out of the
# screen frame. Replaces upstream's root CMakeLists, which needs the whole
# plugin's dependency set (qalculate, pipewire, aubio, cava, …).
cmake_minimum_required(VERSION 3.19)
project(caelestia-blobs LANGUAGES CXX)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick ShaderTools)
qt_standard_project_setup(REQUIRES 6.9)

set(BLOBS plugin/src/Caelestia/Blobs)

# Backing library and plugin in one MODULE, installed as a plain QML module dir.
qt_add_qml_module(caelestia-blobs
    URI Caelestia.Blobs
    VERSION 1.0
    PLUGIN_TARGET caelestia-blobs
    OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml/Caelestia/Blobs"
    SOURCES
        ${BLOBS}/blobgroup.cpp
        ${BLOBS}/blobshape.cpp
        ${BLOBS}/blobrect.cpp
        ${BLOBS}/blobinvertedrect.cpp
        ${BLOBS}/blobmaterial.cpp
)

# the generated type registrations include the headers by bare name
target_include_directories(caelestia-blobs PRIVATE ${BLOBS})
# upstream gets these through its shared precompiled header
target_precompile_headers(caelestia-blobs PRIVATE <qobject.h> <qqmlintegration.h> <qqmlengine.h>)
target_link_libraries(caelestia-blobs PRIVATE Qt::Core Qt::Gui Qt::Qml Qt::Quick)

# blobmaterial.cpp loads :/shaders/blob.{vert,frag}.qsb
qt_add_shaders(caelestia-blobs "blob_shaders"
    BATCHABLE OPTIMIZED NOHLSL NOMSL
    GLSL "300es,330"
    PREFIX "/"
    BASE ${BLOBS}
    FILES
        ${BLOBS}/shaders/blob.frag
        ${BLOBS}/shaders/blob.vert
)

qt_query_qml_module(caelestia-blobs QMLDIR blobs_qmldir TYPEINFO blobs_typeinfo)
set(blobs_dest "${INSTALL_QMLDIR}/Caelestia/Blobs")
install(TARGETS caelestia-blobs LIBRARY DESTINATION "${blobs_dest}")
install(FILES "${blobs_qmldir}" "${blobs_typeinfo}" DESTINATION "${blobs_dest}")
