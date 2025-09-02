include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(mandelbrot_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(mandelbrot_setup_options)
  option(mandelbrot_ENABLE_HARDENING "Enable hardening" ON)
  option(mandelbrot_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    mandelbrot_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    mandelbrot_ENABLE_HARDENING
    OFF)

  mandelbrot_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR mandelbrot_PACKAGING_MAINTAINER_MODE)
    option(mandelbrot_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(mandelbrot_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(mandelbrot_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(mandelbrot_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(mandelbrot_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(mandelbrot_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(mandelbrot_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(mandelbrot_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(mandelbrot_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(mandelbrot_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(mandelbrot_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(mandelbrot_ENABLE_PCH "Enable precompiled headers" OFF)
    option(mandelbrot_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(mandelbrot_ENABLE_IPO "Enable IPO/LTO" ON)
    option(mandelbrot_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(mandelbrot_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(mandelbrot_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(mandelbrot_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(mandelbrot_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(mandelbrot_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(mandelbrot_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(mandelbrot_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(mandelbrot_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(mandelbrot_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(mandelbrot_ENABLE_PCH "Enable precompiled headers" OFF)
    option(mandelbrot_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      mandelbrot_ENABLE_IPO
      mandelbrot_WARNINGS_AS_ERRORS
      mandelbrot_ENABLE_USER_LINKER
      mandelbrot_ENABLE_SANITIZER_ADDRESS
      mandelbrot_ENABLE_SANITIZER_LEAK
      mandelbrot_ENABLE_SANITIZER_UNDEFINED
      mandelbrot_ENABLE_SANITIZER_THREAD
      mandelbrot_ENABLE_SANITIZER_MEMORY
      mandelbrot_ENABLE_UNITY_BUILD
      mandelbrot_ENABLE_CLANG_TIDY
      mandelbrot_ENABLE_CPPCHECK
      mandelbrot_ENABLE_COVERAGE
      mandelbrot_ENABLE_PCH
      mandelbrot_ENABLE_CACHE)
  endif()

  mandelbrot_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (mandelbrot_ENABLE_SANITIZER_ADDRESS OR mandelbrot_ENABLE_SANITIZER_THREAD OR mandelbrot_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(mandelbrot_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(mandelbrot_global_options)
  if(mandelbrot_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    mandelbrot_enable_ipo()
  endif()

  mandelbrot_supports_sanitizers()

  if(mandelbrot_ENABLE_HARDENING AND mandelbrot_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR mandelbrot_ENABLE_SANITIZER_UNDEFINED
       OR mandelbrot_ENABLE_SANITIZER_ADDRESS
       OR mandelbrot_ENABLE_SANITIZER_THREAD
       OR mandelbrot_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${mandelbrot_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${mandelbrot_ENABLE_SANITIZER_UNDEFINED}")
    mandelbrot_enable_hardening(mandelbrot_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(mandelbrot_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(mandelbrot_warnings INTERFACE)
  add_library(mandelbrot_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  mandelbrot_set_project_warnings(
    mandelbrot_warnings
    ${mandelbrot_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(mandelbrot_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    mandelbrot_configure_linker(mandelbrot_options)
  endif()

  include(cmake/Sanitizers.cmake)
  mandelbrot_enable_sanitizers(
    mandelbrot_options
    ${mandelbrot_ENABLE_SANITIZER_ADDRESS}
    ${mandelbrot_ENABLE_SANITIZER_LEAK}
    ${mandelbrot_ENABLE_SANITIZER_UNDEFINED}
    ${mandelbrot_ENABLE_SANITIZER_THREAD}
    ${mandelbrot_ENABLE_SANITIZER_MEMORY})

  set_target_properties(mandelbrot_options PROPERTIES UNITY_BUILD ${mandelbrot_ENABLE_UNITY_BUILD})

  if(mandelbrot_ENABLE_PCH)
    target_precompile_headers(
      mandelbrot_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(mandelbrot_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    mandelbrot_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(mandelbrot_ENABLE_CLANG_TIDY)
    mandelbrot_enable_clang_tidy(mandelbrot_options ${mandelbrot_WARNINGS_AS_ERRORS})
  endif()

  if(mandelbrot_ENABLE_CPPCHECK)
    mandelbrot_enable_cppcheck(${mandelbrot_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(mandelbrot_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    mandelbrot_enable_coverage(mandelbrot_options)
  endif()

  if(mandelbrot_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(mandelbrot_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(mandelbrot_ENABLE_HARDENING AND NOT mandelbrot_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR mandelbrot_ENABLE_SANITIZER_UNDEFINED
       OR mandelbrot_ENABLE_SANITIZER_ADDRESS
       OR mandelbrot_ENABLE_SANITIZER_THREAD
       OR mandelbrot_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    mandelbrot_enable_hardening(mandelbrot_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
