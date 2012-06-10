require 'formula'

class OpenResty < Formula
  homepage 'http://openresty.org/'
  url 'http://agentzh.org/misc/nginx/ngx_openresty-1.0.11.28.tar.gz'
  sha1 '2c32743b0395226fdbe80edbcb77ada4230dd906'

  devel do
    url 'http://agentzh.org/misc/nginx/ngx_openresty-1.0.15.9.tar.gz'
    sha1 'da9ef4c58a1384f4ba50923eac91a078a9ab286e'
  end

  depends_on 'pcre'
  depends_on 'libdrizzle' if ARGV.include? '--with-drizzle'

  skip_clean 'logs'

  # Changes default port to 8080
  def patches
    DATA
  end

  def options
    [
      ['--with-luajit', "Compile with support for the Lua Just-In-Time Compiler"],
      ['--with-http_drizzle_module',    "Compile with support for upstream communication with MySQL and/or Drizzle database servers"]
      ['--with-http_postgres_module', 'Compile with support for direct communication with PostgreSQL database servers']
      ['--with-http_iconv_module', 'Compile with support for converting character encodings']
    ]
  end

  def passenger_config_args
      passenger_root = `passenger-config --root`.chomp

      if File.directory?(passenger_root)
        return "--add-module=#{passenger_root}/ext/nginx"
      end

      puts "Unable to install nginx with passenger support. The passenger"
      puts "gem must be installed and passenger-config must be in your path"
      puts "in order to continue."
      exit
  end

  def install
    args = ["--prefix=#{prefix}",
            "--with-http_ssl_module",
            "--with-pcre",
            "--with-cc-opt='-I#{HOMEBREW_PREFIX}/include'",
            "--with-ld-opt='-L#{HOMEBREW_PREFIX}/lib'",
            "--sbin-path=#{sbin}/openresty",
            "--conf-path=#{etc}/openresty/nginx.conf",
            "--pid-path=#{var}/run/openresty.pid",
            "--lock-path=#{var}/openresty/nginx.lock"]

    # nginx passthrough
    args << passenger_config_args if ARGV.include? '--with-passenger'
    args << "--with-http_dav_module" if ARGV.include? '--with-webdav'
    
    # OpenResty options
    args << "--with-luajit" if ARGV.include? '--with-luajit'
    args << "--with-http_drizzle_module" if ARGV.include? '--with-drizzle'
    args << "--with-http_postgres_module" if ARGV.include? '--with-postgres'
    args << "--with-http_iconv_module" if ARGV.include? '--with-iconv'

    system "./configure", *args
    system "make"
    system "make install"
    man8.install "objs/nginx.8"

    plist_path.write startup_plist
    plist_path.chmod 0644
  end

  def caveats; <<-EOS.undent
    OpenResty is a beefed up version of nginx, but in order to play nice with
    the standard `nginx` formula, this installer will rename the executable
    `openresty`, and place configuration files in separate directories. This
    allows you to have both nginx and OpenResty nginx installed at the same
    time.
    
    In the interest of allowing you to run `openresty` without `sudo`, the
    default port is set to localhost:8080.

    If you want to host pages on your local machine to the public, you should
    change that to localhost:80, and run `sudo openresty`. You'll need to turn
    off any other web servers running port 80, of course.

    You can start openresty automatically on login running as your user with:
      mkdir -p ~/Library/LaunchAgents
      cp #{plist_path} ~/Library/LaunchAgents/
      launchctl load -w ~/Library/LaunchAgents/#{plist_path.basename}

    Caution: when running as your user (not root) the launch agent will fail
    if you try to use a port below 1024 (such as http's default of 80).
    EOS
  end

  def startup_plist
    return <<-EOPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>#{plist_name}</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>UserName</key>
    <string>#{`whoami`.chomp}</string>
    <key>ProgramArguments</key>
    <array>
        <string>#{HOMEBREW_PREFIX}/sbin/openresty</string>
        <string>-g</string>
        <string>daemon off;</string>
    </array>
    <key>WorkingDirectory</key>
    <string>#{HOMEBREW_PREFIX}</string>
  </dict>
</plist>
    EOPLIST
  end
end

__END__
--- a/conf/nginx.conf
+++ b/conf/nginx.conf
@@ -33,7 +33,7 @@
     #gzip  on;

     server {
-        listen       80;
+        listen       8080;
         server_name  localhost;

         #charset koi8-r;
