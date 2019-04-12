class Cpprestsdk < Formula
  desc "C++ libraries for cloud-based client-server communication"
  homepage "https://github.com/Microsoft/cpprestsdk"
  # pull from git tag to get submodules
  url "https://github.com/Microsoft/cpprestsdk.git",
      :tag      => "v2.10.13",
      :revision => "9d8f544001cb74544de6dc8c565592f7e2626d6e"
  revision 1
  head "https://github.com/Microsoft/cpprestsdk.git", :branch => "development"

  bottle do
    cellar :any
    sha256 "8690db034a59516774eb5e3d7b7d986d86054ea1ada3df2a341ed34a7c50d610" => :mojave
    sha256 "8cac36203d1916c8f07bf1d79aa081f849c103c24ddd8479ec45f0cef869d1a3" => :high_sierra
    sha256 "051cf1caed37d1f15c12f898308776ab57f014a92789ea138fa65f53bb2c4c62" => :sierra
  end

  depends_on "cmake" => :build
  depends_on "boost"
  depends_on "openssl"

  # Fix for boost 1.70.0 https://github.com/microsoft/cpprestsdk/issues/1054
  # From websocketpp pull request https://github.com/zaphoyd/websocketpp/pull/814
  patch :DATA

  def install
    system "cmake", "-DBUILD_SAMPLES=OFF", "-DBUILD_TESTS=OFF", "Release", *std_cmake_args
    system "make", "install"
  end

  test do
    (testpath/"test.cc").write <<~EOS
      #include <iostream>
      #include <cpprest/http_client.h>
      int main() {
        web::http::client::http_client client(U("https://github.com/"));
        std::cout << client.request(web::http::methods::GET).get().extract_string().get() << std::endl;
      }
    EOS
    flags = ["-stdlib=libc++", "-std=c++11", "-I#{include}",
             "-I#{Formula["boost"].include}",
             "-I#{Formula["openssl"].include}", "-L#{lib}",
             "-L#{Formula["openssl"].lib}", "-L#{Formula["boost"].lib}",
             "-lssl", "-lcrypto", "-lboost_random", "-lboost_chrono",
             "-lboost_thread-mt", "-lboost_system-mt", "-lboost_regex",
             "-lboost_filesystem", "-lcpprest"] + ENV.cflags.to_s.split
    system ENV.cxx, "-o", "test_cpprest", "test.cc", *flags
    system "./test_cpprest"
  end
end

__END__
diff -pur a/Release/libs/websocketpp/websocketpp/transport/asio/connection.hpp b/Release/libs/websocketpp/websocketpp/transport/asio/connection.hpp
--- a/Release/libs/websocketpp/websocketpp/transport/asio/connection.hpp	2019-06-08 17:26:20.000000000 +0200
+++ b/Release/libs/websocketpp/websocketpp/transport/asio/connection.hpp	2019-06-08 17:23:38.000000000 +0200
@@ -311,9 +311,8 @@ public:
      * needed.
      */
     timer_ptr set_timer(long duration, timer_handler callback) {
-        timer_ptr new_timer = lib::make_shared<lib::asio::steady_timer>(
-            lib::ref(*m_io_service),
-            lib::asio::milliseconds(duration)
+        timer_ptr new_timer(
+	    new lib::asio::steady_timer(*m_io_service, lib::asio::milliseconds(duration))
         );

         if (config::enable_multithreading) {
@@ -461,8 +460,7 @@ protected:
         m_io_service = io_service;

         if (config::enable_multithreading) {
-            m_strand = lib::make_shared<lib::asio::io_service::strand>(
-                lib::ref(*io_service));
+            m_strand.reset(new lib::asio::io_service::strand(*io_service));
         }

         lib::error_code ec = socket_con_type::init_asio(io_service, m_strand,
diff -pur a/Release/libs/websocketpp/websocketpp/transport/asio/endpoint.hpp b/Release/libs/websocketpp/websocketpp/transport/asio/endpoint.hpp
--- a/Release/libs/websocketpp/websocketpp/transport/asio/endpoint.hpp	2019-06-08 17:26:20.000000000 +0200
+++ b/Release/libs/websocketpp/websocketpp/transport/asio/endpoint.hpp	2019-06-08 17:24:25.000000000 +0200
@@ -195,8 +195,7 @@ public:

         m_io_service = ptr;
         m_external_io_service = true;
-        m_acceptor = lib::make_shared<lib::asio::ip::tcp::acceptor>(
-            lib::ref(*m_io_service));
+        m_acceptor.reset(new lib::asio::ip::tcp::acceptor(*m_io_service));

         m_state = READY;
         ec = lib::error_code();
@@ -688,9 +687,7 @@ public:
      * @since 0.3.0
      */
     void start_perpetual() {
-        m_work = lib::make_shared<lib::asio::io_service::work>(
-            lib::ref(*m_io_service)
-        );
+        m_work.reset(new lib::asio::io_service::work(*m_io_service));
     }

     /// Clears the endpoint's perpetual flag, allowing it to exit when empty
@@ -854,8 +851,7 @@ protected:

         // Create a resolver
         if (!m_resolver) {
-            m_resolver = lib::make_shared<lib::asio::ip::tcp::resolver>(
-                lib::ref(*m_io_service));
+            m_resolver.reset(new lib::asio::ip::tcp::resolver(*m_io_service));
         }

         tcon->set_uri(u);
diff -pur a/Release/libs/websocketpp/websocketpp/transport/asio/security/none.hpp b/Release/libs/websocketpp/websocketpp/transport/asio/security/none.hpp
--- a/Release/libs/websocketpp/websocketpp/transport/asio/security/none.hpp	2019-06-08 17:26:20.000000000 +0200
+++ b/Release/libs/websocketpp/websocketpp/transport/asio/security/none.hpp	2019-06-08 17:24:44.000000000 +0200
@@ -168,8 +168,7 @@ protected:
             return socket::make_error_code(socket::error::invalid_state);
         }

-        m_socket = lib::make_shared<lib::asio::ip::tcp::socket>(
-            lib::ref(*service));
+        m_socket.reset(new lib::asio::ip::tcp::socket(*service));

         if (m_socket_init_handler) {
             m_socket_init_handler(m_hdl, *m_socket);
diff -pur a/Release/libs/websocketpp/websocketpp/transport/asio/security/tls.hpp b/Release/libs/websocketpp/websocketpp/transport/asio/security/tls.hpp
--- a/Release/libs/websocketpp/websocketpp/transport/asio/security/tls.hpp	2019-06-08 17:26:20.000000000 +0200
+++ b/Release/libs/websocketpp/websocketpp/transport/asio/security/tls.hpp	2019-06-08 17:25:04.000000000 +0200
@@ -193,8 +193,7 @@ protected:
         if (!m_context) {
             return socket::make_error_code(socket::error::invalid_tls_context);
         }
-        m_socket = lib::make_shared<socket_type>(
-            _WEBSOCKETPP_REF(*service),lib::ref(*m_context));
+        m_socket.reset(new socket_type(*service, *m_context));

         if (m_socket_init_handler) {
             m_socket_init_handler(m_hdl, get_socket());
