#!/bin/bash
# Patch apllying tool template
# v0.1.2
# (c) Copyright 2013. Magento Inc.
#
# DO NOT CHANGE ANY LINE IN THIS FILE.

# 1. Check required system tools
_check_installed_tools() {
    local missed=""

    until [ -z "$1" ]; do
        type -t $1 >/dev/null 2>/dev/null
        if (( $? != 0 )); then
            missed="$missed $1"
        fi
        shift
    done

    echo $missed
}

REQUIRED_UTILS='sed patch'
MISSED_REQUIRED_TOOLS=`_check_installed_tools $REQUIRED_UTILS`
if (( `echo $MISSED_REQUIRED_TOOLS | wc -w` > 0 ));
then
    echo -e "Error! Some required system tools, that are utilized in this sh script, are not installed:\nTool(s) \"$MISSED_REQUIRED_TOOLS\" is(are) missed, please install it(them)."
    exit 1
fi

# 2. Determine bin path for system tools
CAT_BIN=`which cat`
PATCH_BIN=`which patch`
SED_BIN=`which sed`
PWD_BIN=`which pwd`
BASENAME_BIN=`which basename`

BASE_NAME=`$BASENAME_BIN "$0"`

# 3. Help menu
if [ "$1" = "-?" -o "$1" = "-h" -o "$1" = "--help" ]
then
    $CAT_BIN << EOFH
Usage: sh $BASE_NAME [--help] [-R|--revert] [--list]
Apply embedded patch.

-R, --revert    Revert previously applied embedded patch
--list          Show list of applied patches
--help          Show this help message
EOFH
    exit 0
fi

# 4. Get "revert" flag and "list applied patches" flag
REVERT_FLAG=
SHOW_APPLIED_LIST=0
if [ "$1" = "-R" -o "$1" = "--revert" ]
then
    REVERT_FLAG=-R
fi
if [ "$1" = "--list" ]
then
    SHOW_APPLIED_LIST=1
fi

# 5. File pathes
CURRENT_DIR=`$PWD_BIN`/
APP_ETC_DIR=`echo "$CURRENT_DIR""app/etc/"`
APPLIED_PATCHES_LIST_FILE=`echo "$APP_ETC_DIR""applied.patches.list"`

# 6. Show applied patches list if requested
if [ "$SHOW_APPLIED_LIST" -eq 1 ] ; then
    echo -e "Applied/reverted patches list:"
    if [ -e "$APPLIED_PATCHES_LIST_FILE" ]
    then
        if [ ! -r "$APPLIED_PATCHES_LIST_FILE" ]
        then
            echo "ERROR: \"$APPLIED_PATCHES_LIST_FILE\" must be readable so applied patches list can be shown."
            exit 1
        else
            $SED_BIN -n "/SUP-\|SUPEE-/p" $APPLIED_PATCHES_LIST_FILE
        fi
    else
        echo "<empty>"
    fi
    exit 0
fi

# 7. Check applied patches track file and its directory
_check_files() {
    if [ ! -e "$APP_ETC_DIR" ]
    then
        echo "ERROR: \"$APP_ETC_DIR\" must exist for proper tool work."
        exit 1
    fi

    if [ ! -w "$APP_ETC_DIR" ]
    then
        echo "ERROR: \"$APP_ETC_DIR\" must be writeable for proper tool work."
        exit 1
    fi

    if [ -e "$APPLIED_PATCHES_LIST_FILE" ]
    then
        if [ ! -w "$APPLIED_PATCHES_LIST_FILE" ]
        then
            echo "ERROR: \"$APPLIED_PATCHES_LIST_FILE\" must be writeable for proper tool work."
            exit 1
        fi
    fi
}

_check_files

# 8. Apply/revert patch
# Note: there is no need to check files permissions for files to be patched.
# "patch" tool will not modify any file if there is not enough permissions for all files to be modified.
# Get start points for additional information and patch data
SKIP_LINES=$((`$SED_BIN -n "/^__PATCHFILE_FOLLOWS__$/=" "$CURRENT_DIR""$BASE_NAME"` + 1))
ADDITIONAL_INFO_LINE=$(($SKIP_LINES - 3))p

_apply_revert_patch() {
    DRY_RUN_FLAG=
    if [ "$1" = "dry-run" ]
    then
        DRY_RUN_FLAG=" --dry-run"
        echo "Checking if patch can be applied/reverted successfully..."
    fi
    PATCH_APPLY_REVERT_RESULT=`$SED_BIN -e '1,/^__PATCHFILE_FOLLOWS__$/d' "$CURRENT_DIR""$BASE_NAME" | $PATCH_BIN $DRY_RUN_FLAG $REVERT_FLAG -p0`
    PATCH_APPLY_REVERT_STATUS=$?
    if [ $PATCH_APPLY_REVERT_STATUS -eq 1 ] ; then
        echo -e "ERROR: Patch can't be applied/reverted successfully.\n\n$PATCH_APPLY_REVERT_RESULT"
        exit 1
    fi
    if [ $PATCH_APPLY_REVERT_STATUS -eq 2 ] ; then
        echo -e "ERROR: Patch can't be applied/reverted successfully."
        exit 2
    fi
}

REVERTED_PATCH_MARK=
if [ -n "$REVERT_FLAG" ]
then
    REVERTED_PATCH_MARK=" | REVERTED"
fi

_apply_revert_patch dry-run
_apply_revert_patch

# 9. Track patch applying result
echo "Patch was applied/reverted successfully."
ADDITIONAL_INFO=`$SED_BIN -n ""$ADDITIONAL_INFO_LINE"" "$CURRENT_DIR""$BASE_NAME"`
APPLIED_REVERTED_ON_DATE=`date -u +"%F %T UTC"`
APPLIED_REVERTED_PATCH_INFO=`echo -n "$APPLIED_REVERTED_ON_DATE"" | ""$ADDITIONAL_INFO""$REVERTED_PATCH_MARK"`
echo -e "$APPLIED_REVERTED_PATCH_INFO\n$PATCH_APPLY_REVERT_RESULT\n\n" >> "$APPLIED_PATCHES_LIST_FILE"

exit 0


SUPEE-3941_EE_1_10 | EE_1.10.1.0 | v1 | 95c0191f983f9ccbfac4c63dba876b2b298c3f13 | Thu Jul 17 21:46:24 2014 +0300 | v1.10.1.0..HEAD

__PATCHFILE_FOLLOWS__
diff --git downloader/lib/Mage/Connect/Packager.php downloader/lib/Mage/Connect/Packager.php
index 0e9ef0d..f451399 100644
--- downloader/lib/Mage/Connect/Packager.php
+++ downloader/lib/Mage/Connect/Packager.php
@@ -193,8 +193,15 @@ class Mage_Connect_Packager
                 }
             }
         } else {
-            if (@rmdir($dir)) {
-                $this->removeEmptyDirectory(dirname($dir), $ftp);
+            $content = scandir($dir);
+            if ($content === false) return;
+
+            if (count(array_diff($content, array('.', '..'))) == 0) {
+                if (@rmdir($dir)) {
+                    $this->removeEmptyDirectory(dirname($dir), $ftp);
+                } else {
+                    throw new RuntimeException('Failed to delete dir ' . $dir . "\r\n Check permissions");
+                }
             }
         }
     }
@@ -205,6 +212,7 @@ class Mage_Connect_Packager
      * @param $package
      * @param Mage_Connect_Singleconfig $cacheObj
      * @param Mage_Connect_Config $configObj
+     * @throws RuntimeException
      * @return unknown_type
      */
     public function processUninstallPackage($chanName, $package, $cacheObj, $configObj)
@@ -213,14 +221,21 @@ class Mage_Connect_Packager
         $contents = $package->getContents();
 
         $targetPath = rtrim($configObj->magento_root, "\\/");
+        $failedFiles = array();
         foreach($contents as $file) {
             $fileName = basename($file);
             $filePath = dirname($file);
             $dest = $targetPath . DIRECTORY_SEPARATOR . $filePath . DIRECTORY_SEPARATOR . $fileName;
             if(@file_exists($dest)) {
-                @unlink($dest);
-                $this->removeEmptyDirectory(dirname($dest));
+                if (!@unlink($dest)) {
+                    $failedFiles[] = $dest;
+                }
             }
+            $this->removeEmptyDirectory(dirname($dest));
+        }
+        if (!empty($failedFiles)) {
+            $msg = sprintf("Failed to delete files: %s \r\n Check permissions", implode("\r\n", $failedFiles));
+            throw new RuntimeException($msg);
         }
 
         $destDir = $targetPath . DS . Mage_Connect_Package::PACKAGE_XML_DIR;
@@ -234,6 +249,7 @@ class Mage_Connect_Packager
      * @param $package
      * @param Mage_Connect_Singleconfig $cacheObj
      * @param Mage_Connect_Ftp $ftp
+     * @throws RuntimeException
      * @return unknown_type
      */
     public function processUninstallPackageFtp($chanName, $package, $cacheObj, $ftp)
@@ -241,10 +257,15 @@ class Mage_Connect_Packager
         $ftpDir = $ftp->getcwd();
         $package = $cacheObj->getPackageObject($chanName, $package);
         $contents = $package->getContents();
+        $failedFiles = array();
         foreach($contents as $file) {
             $res = $ftp->delete($file);
             $this->removeEmptyDirectory(dirname($file), $ftp);
         }
+        if (!empty($failedFiles)) {
+            $msg = sprintf("Failed to delete files: %s \r\n Check permissions", implode("\r\n", $failedFiles));
+            throw new RuntimeException($msg);
+        }
         $remoteXml = Mage_Connect_Package::PACKAGE_XML_DIR . DS . $package->getReleaseFilename() . '.xml';
         $ftp->delete($remoteXml);
         $ftp->chdir($ftpDir);
@@ -316,7 +337,18 @@ class Mage_Connect_Packager
         $tar = $arc->unpack($file, $target);
         $modeFile = $this->_getFileMode($configObj);
         $modeDir = $this->_getDirMode($configObj);
+        $targetPath = rtrim($configObj->magento_root, "\\/");
+        $packageXmlDir = $targetPath . DS . Mage_Connect_Package::PACKAGE_XML_DIR;
+        if (!is_dir_writeable($packageXmlDir)) {
+            throw new RuntimeException('Directory ' . $packageXmlDir . ' is not writable. Check permission');
+        }
+        $this->_makeDirectories($contents, $targetPath, $modeDir);
         foreach($contents as $file) {
+            $ftp->delete($file);
+            if ($ftp->fileExists($file)) {
+                $failedFiles[] = $file;
+                continue;
+            }
             $fileName = basename($file);
             $filePath = $this->convertFtpPath(dirname($file));
             $source = $tar.DS.$file;
@@ -326,11 +358,18 @@ class Mage_Connect_Packager
                     $args[] = $modeDir;
                     $args[] = $modeFile;
                 }
-                call_user_func_array(array($ftp,'upload'), $args);
+                if (call_user_func_array(array($ftp,'upload'), $args) === false) {
+                    $failedFiles[] = $source;
+                }
             }
         }
 
         $localXml = $tar . Mage_Connect_Package_Reader::DEFAULT_NAME_PACKAGE;
+
+        if (!empty($failedFiles)) {
+            $msg = sprintf("Failed to upload files: %s \r\n Check permissions", implode("\r\n", $failedFiles));
+            throw new RuntimeException($msg);
+        }
         if (is_file($localXml)) {
             $remoteXml = Mage_Connect_Package::PACKAGE_XML_DIR . DS . $package->getReleaseFilename() . '.xml';
             $ftp->upload($remoteXml, $localXml, $modeDir, $modeFile);
@@ -344,7 +383,7 @@ class Mage_Connect_Packager
      * Package installation to FS
      * @param Mage_Connect_Package $package
      * @param string $file
-     * @return void
+     * @throws RuntimeException
      * @throws Exception
      */
     public function processInstallPackage($package, $file, $configObj)
@@ -352,16 +391,19 @@ class Mage_Connect_Packager
         $contents = $package->getContents();
         $arc = $this->getArchiver();
         $target = dirname($file).DS.$package->getReleaseFilename();
-        @mkdir($target, 0777, true);
+        if (!@mkdir($target, 0777, true)) {
+            throw new RuntimeException("Can't create directory ". $target);
+        }
         $tar = $arc->unpack($file, $target);
         $modeFile = $this->_getFileMode($configObj);
         $modeDir = $this->_getDirMode($configObj);
+        $failedFiles = array();
         foreach($contents as $file) {
             $fileName = basename($file);
             $filePath = dirname($file);
             $source = $tar.DS.$file;
             $targetPath = rtrim($configObj->magento_root, "\\/");
-            @mkdir($targetPath. DS . $filePath, $modeDir, true);
+            $source = $tar . DS . $file;
             $dest = $targetPath . DS . $filePath . DS . $fileName;
             if (is_file($source)) {
                 @copy($source, $dest);
@@ -386,6 +428,36 @@ class Mage_Connect_Packager
         Mage_System_Dirs::rm(array("-r",$target));
     }
 
+    /**
+     * @param array $content
+     * @param string $targetPath
+     * @param int $modeDir
+     * @throws RuntimeException
+     */
+    protected function _makeDirectories($content, $targetPath, $modeDir)
+    {
+        $failedDirs = array();
+        $createdDirs = array();
+        foreach ($content as $file) {
+            $dirPath = dirname($file);
+            if (is_dir($dirPath) && is_dir_writeable($dirPath)) {
+                continue;
+            }
+            if (!mkdir($targetPath . DS . $dirPath, $modeDir, true)) {
+                $failedDirs[] = $targetPath . DS .  $dirPath;
+            } else {
+                $createdDirs[] = $targetPath . DS . $dirPath;
+            }
+        }
+        if (!empty($failedDirs)) {
+            foreach ($createdDirs as $createdDir) {
+                $this->removeEmptyDirectory($createdDir);
+            }
+            $msg = sprintf("Failed to create directory:\r\n%s\r\n Check permissions", implode("\r\n", $failedDirs));
+            throw new RuntimeException($msg);
+        }
+    }
+
 
     /**
      * Get local modified files
@@ -415,6 +487,7 @@ class Mage_Connect_Packager
      * @param $package
      * @param $cacheObj
      * @param Mage_Connect_Ftp $ftp
+     * @throws RuntimeException
      * @return array
      */
     public function getRemoteModifiedFiles($chanName, $package, $cacheObj, $ftp)
diff --git downloader/lib/Mage/Connect/Rest.php downloader/lib/Mage/Connect/Rest.php
index 8d983f0..e734bbd 100644
--- downloader/lib/Mage/Connect/Rest.php
+++ downloader/lib/Mage/Connect/Rest.php
@@ -71,17 +71,14 @@ class Mage_Connect_Rest
     /**
      * Constructor
      */
-    public function __construct($protocol="http")
+    public function __construct($protocol="https")
     {
         switch ($protocol) {
-            case 'ftp':
-                $this->_protocol = 'ftp';
-                break;
             case 'http':
                 $this->_protocol = 'http';
                 break;
             default:
-                $this->_protocol = 'http';
+                $this->_protocol = 'https';
                 break;
         }
     }
diff --git downloader/lib/Mage/Connect/Singleconfig.php downloader/lib/Mage/Connect/Singleconfig.php
index ece5424..38e7fb2 100644
--- downloader/lib/Mage/Connect/Singleconfig.php
+++ downloader/lib/Mage/Connect/Singleconfig.php
@@ -100,7 +100,6 @@ class Mage_Connect_Singleconfig
         $uri = rtrim($uri, "/");
         $uri = str_replace("http://", '', $uri);
         $uri = str_replace("https://", '', $uri);
-        $uri = str_replace("ftp://", '', $uri);
         return $uri;
     }
 
diff --git downloader/lib/Mage/HTTP/Client/Curl.php downloader/lib/Mage/HTTP/Client/Curl.php
index 3cb9b42..f7826e1 100644
--- downloader/lib/Mage/HTTP/Client/Curl.php
+++ downloader/lib/Mage/HTTP/Client/Curl.php
@@ -361,47 +361,20 @@ implements Mage_HTTP_IClient
 
     /**
      * Make request
+     *
      * @param string $method
      * @param string $uri
      * @param array $params
-     * @return null
+     * @param boolean $isAuthorizationRequired
      */
-    protected function makeRequest($method, $uri, $params = array())
+    protected function makeRequest($method, $uri, $params = array(), $isAuthorizationRequired = true)
     {
-        static $isAuthorizationRequired = 0;
+        $uriModified = $this->getSecureRequest($uri, $isAuthorizationRequired);
         $this->_ch = curl_init();
-
-        // make request via secured layer
-        if ($isAuthorizationRequired && strpos($uri, 'https://') !== 0) {
-            $uri = str_replace('http://', '', $uri);
-            $uri = 'https://' . $uri;
-        }
-
-        $this->curlOption(CURLOPT_URL, $uri);
-        $this->curlOption(CURLOPT_SSL_VERIFYPEER, FALSE);
+        $this->curlOption(CURLOPT_URL, $uriModified);
+        $this->curlOption(CURLOPT_SSL_VERIFYPEER, false);
         $this->curlOption(CURLOPT_SSL_VERIFYHOST, 2);
-
-        // force method to POST if secured
-        if ($isAuthorizationRequired) {
-            $method = 'POST';
-        }
-
-        if($method == 'POST') {
-            $this->curlOption(CURLOPT_POST, 1);
-            $postFields = is_array($params) ? $params : array();
-            if ($isAuthorizationRequired) {
-                $this->curlOption(CURLOPT_COOKIEJAR, self::COOKIE_FILE);
-                $this->curlOption(CURLOPT_COOKIEFILE, self::COOKIE_FILE);
-                $postFields = array_merge($postFields, $this->_auth);
-            }
-            if (!empty($postFields)) {
-                $this->curlOption(CURLOPT_POSTFIELDS, $postFields);
-            }
-        } elseif($method == "GET") {
-            $this->curlOption(CURLOPT_HTTPGET, 1);
-        } else {
-            $this->curlOption(CURLOPT_CUSTOMREQUEST, $method);
-        }
+        $this->getCurlMethodSettings($method, $params, $isAuthorizationRequired);
 
         if(count($this->_headers)) {
             $heads = array();
@@ -444,23 +417,26 @@ implements Mage_HTTP_IClient
             $this->doError(curl_error($this->_ch));
         }
         if(!$this->getStatus()) {
-            return $this->doError("Invalid response headers returned from server.");
+            $this->doError("Invalid response headers returned from server.");
+            return;
         }
+
         curl_close($this->_ch);
+
         if (403 == $this->getStatus()) {
-            if (!$isAuthorizationRequired) {
-                $isAuthorizationRequired++;
-                $this->makeRequest($method, $uri, $params);
-                $isAuthorizationRequired=0;
+            if ($isAuthorizationRequired) {
+                $this->makeRequest($method, $uri, $params, false);
             } else {
-                return $this->doError(sprintf('Access denied for %s@%s', $_SESSION['auth']['login'], $uri));
+                $this->doError(sprintf('Access denied for %s@%s', $_SESSION['auth']['login'], $uriModified));
+                return;
             }
+        } elseif (405 == $this->getStatus()) {
+            $this->doError("HTTP Error 405 Method not allowed");
+            return;
         }
     }
 
     /**
-     * Throw error excpetion
-     * @param $string
      * @throws Exception
      */
     public function isAuthorizationRequired()
@@ -553,4 +529,44 @@ implements Mage_HTTP_IClient
     {
         $this->_curlUserOptions[$name] = $value;
     }
+
+    /**
+     * @param $uri
+     * @param $isAuthorizationRequired
+     * @return string
+     */
+    protected function getSecureRequest($uri, $isAuthorizationRequired = true)
+    {
+        if ($isAuthorizationRequired && strpos($uri, 'https://') !== 0) {
+            $uri = str_replace('http://', '', $uri);
+            $uri = 'https://' . $uri;
+            return $uri;
+        }
+        return $uri;
+    }
+
+    /**
+     * @param $method
+     * @param $params
+     * @param $isAuthorizationRequired
+     */
+    protected function getCurlMethodSettings($method, $params, $isAuthorizationRequired)
+    {
+        if ($method == 'POST') {
+            $this->curlOption(CURLOPT_POST, 1);
+            $postFields = is_array($params) ? $params : array();
+            if ($isAuthorizationRequired) {
+                $this->curlOption(CURLOPT_COOKIEJAR, self::COOKIE_FILE);
+                $this->curlOption(CURLOPT_COOKIEFILE, self::COOKIE_FILE);
+                $postFields = array_merge($postFields, $this->_auth);
+            }
+            if (!empty($postFields)) {
+                $this->curlOption(CURLOPT_POSTFIELDS, $postFields);
+            }
+        } elseif ($method == "GET") {
+            $this->curlOption(CURLOPT_HTTPGET, 1);
+        } else {
+            $this->curlOption(CURLOPT_CUSTOMREQUEST, $method);
+        }
+    }
 }
diff --git downloader/template/settings.phtml downloader/template/settings.phtml
index aec1c93..58142d1 100755
--- downloader/template/settings.phtml
+++ downloader/template/settings.phtml
@@ -63,8 +63,8 @@ function changeDeploymentType (element)
                     <td class="label">Magento Connect Channel Protocol:</td>
                     <td class="value">
                         <select id="protocol" name="protocol">
+                            <option value="https" <?php if ($this->get('protocol')=='https'):?>selected="selected"<?php endif ?>>Https</option>
                             <option value="http" <?php if ($this->get('protocol')=='http'):?>selected="selected"<?php endif ?>>Http</option>
-                            <option value="ftp" <?php if ($this->get('protocol')=='ftp'):?>selected="selected"<?php endif ?>>Ftp</option>
                         </select>
                     </td>
                 </tr>
