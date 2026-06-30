if(EXISTS "${CURRENT_PORT_DIR}/../../../src/mlog/CMakeLists.txt")
	set(SOURCE_PATH "${CURRENT_PORT_DIR}/../../..")
	message(STATUS "mlog port: using local workspace ${SOURCE_PATH}")
else()
	vcpkg_from_git(
		OUT_SOURCE_PATH SOURCE_PATH
		URL https://github.com/cuttingdust/api_mlog.git
		REF 48cabd50b13f5e89564e39996c9a9f0cf69469aa
	)
endif()

vcpkg_cmake_configure(
	SOURCE_PATH "${SOURCE_PATH}/src"
	OPTIONS
		-DCMAKE_CXX_STANDARD=20
)

vcpkg_cmake_install()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
vcpkg_cmake_config_fixup(PACKAGE_NAME MLog CONFIG_PATH lib/cmake/MLog)
vcpkg_copy_pdbs()
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
