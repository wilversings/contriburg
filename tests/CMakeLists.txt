cmake_minimum_required(VERSION 3.16)
project(contriburg-tests LANGUAGES CXX)

find_package(Qt6 REQUIRED COMPONENTS Quick Test QmlTools)

enable_testing()

add_test(
    NAME ContriburgTests
    COMMAND Qt6::qmltestrunner -input ${CMAKE_CURRENT_SOURCE_DIR} -import ${CMAKE_CURRENT_SOURCE_DIR}/../contents/ui
)
