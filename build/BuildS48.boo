
// Semi-automatic Windows build script for Scheme 48.

// To prepare to run this script:
// - Download Boo 0.9.2.3383 (from http://dist.codehaus.org/boo/distributions/)
//   and unpack the distribution.
// - Compile this script with booc, and put the resulting EXE in the root
//   directory of the source tree.  For example:
//       ..\..\path\to\booc.exe build\BuildS48.boo
// - Put Boo.Lang.dll in the root directory of the source tree.

// To run this script:
// - Open a Windows command prompt in the root directory of the source tree.
// - Set the RUNNABLE environment variable to the (possibly relative) path to
//   the scheme48.bat file in a working Scheme 48 installation.
// - Run BuildS48.exe.
// - If odd messages appear (errors or unusual warnings), press Control-C to
//   stop the build process, then press Control-C again so that CMD.EXE will
//   print another prompt.  This script currently does not detect most errors.

namespace BuildS48

import System
import System.Diagnostics
import System.IO
import System.Text



// Ensure that current directory contains scheme48.sln and autogen.sh
//     (and is therefore probably the root directory of a Scheme 48
//     development source tree).

filesThatShouldExist = [
	'autogen.sh',
	'scheme48.sln',
	'scheme48.vcproj',
	'README',
	'WINDOWS.txt',
	'build/scheme48.wxs']

for fileName in filesThatShouldExist:
	unless File.Exists(fileName):
		raise "${fileName} is not here - this should be run from the root directory of a Scheme 48 development source tree"



// Define utility functions.

def makeArgs(*args as (string)):
	cmdline = StringBuilder()
	for arg in args:
		cmdline.Append('"')
		for ch in arg:
			if ch == '"':
				cmdline.Append("\"\"")
			else:
				cmdline.Append(ch)
		cmdline.Append("\" ")
	return cmdline.ToString()

def dequote(s as string):
	unless s.StartsWith("\"") and s.EndsWith("\""):
		return s
	s2 = s.Substring(1, s.Length - 2)
	if s2.IndexOf("\"") != -1: // FIXME?
		return s
	return s2

def runWithInput(name as string, *args as (string)):
	si = ProcessStartInfo(name, makeArgs(*args))
	si.UseShellExecute = false
	si.RedirectStandardInput = true
	return Process.Start(si)

def runAndWait(name as string, *args as (string)):
	si = ProcessStartInfo(name, makeArgs(*args))
	si.UseShellExecute = false
	Process.Start(si).WaitForExit()

def stuffProcessInputFromFile(process as Process, inputFileName as string):
	inputFile = StreamReader(inputFileName)
	output = process.StandardInput
	buffer = array(char, 4096)
	rv = 1
	while rv > 0:
		rv = inputFile.Read(buffer, 0, buffer.Length)
		output.Write(buffer, 0, rv)

def closeProcessInput(process as Process):
	process.StandardInput.Close()

def herald(msg as string):
	print
	s = '********'
	s = string.Concat(s, s)
	s = string.Concat(s, s)
	s = string.Concat(s, s)
	print s
	print "**** ${msg}"
	print



// Find an existing (runnable) copy of Scheme 48.

runnable = Environment.GetEnvironmentVariable("RUNNABLE")
if runnable != null:
	print "Found RUNNABLE environment variable"

// TODO? - use Microsoft Installer to find an installed binary distribution?
//     Does Boo have an equivalent to the C# extern keyword?

if runnable == null:
	raise "No runnable specified - please set the RUNNABLE environment variable"

unless File.Exists(runnable):
	if runnable.StartsWith("\""):
		runnableDequoted = dequote(runnable)
	if File.Exists(runnableDequoted):
		runnable = runnableDequoted

print "Using runnable: ${runnable}"
unless File.Exists(runnable):
	raise "Runnable does not exist"



// Build Unicode information, but only if it's *really* necessary.

herald('build/generate-unicode-info.bat')

inputsOfGenUnicodeInfo = [
	"build/UnicodeData.txt",
	"build/PropList.txt",
	"build/SpecialCasing.txt",
	"build/CaseFolding.txt",
	"build/CompositionExclusions.txt"]

outputsOfGenUnicodeInfo = [
	"scheme/env/unicode-info.scm",
	"scheme/rts/syntax-info.scm",
	"scheme/big/unicode-normalization-info.scm",
	"scheme/srfi/srfi-14-base-char-sets.scm"]

guiInputLastMTime = DateTime.FromFileTimeUtc(0)
for input in inputsOfGenUnicodeInfo:
	unless File.Exists(input):
		raise "Required input file ${input} is missing"
	inputMTime = File.GetLastWriteTimeUtc(input)
	if inputMTime > guiInputLastMTime:
		guiInputLastMTime = inputMTime

mustRunGenUnicodeInfo = false
for output in outputsOfGenUnicodeInfo:
	unless File.Exists(output):
		print "Running build/generate-unicode-info.bat because ${output} is missing"
		mustRunGenUnicodeInfo = true
		break
	unless File.GetLastWriteTimeUtc(output) > guiInputLastMTime:
		print "Running build/generate-unicode-info.bat because ${output} is older than an input file"
		mustRunGenUnicodeInfo = true
		break

if mustRunGenUnicodeInfo:
	runAndWait('build/generate-unicode-info.bat', runnable)
else:
	print "Skipping build/generate-unicode-info.bat"



// Build initial image.

herald('%RUNNABLE% -a batch <build/extract-filenames.scm')

p = runWithInput(runnable, '-a', 'batch')
stuffProcessInputFromFile(p, 'build/extract-filenames.scm')
p.StandardInput.Write(',exit\n') // not in extract-filenames.scm because it's portable
closeProcessInput(p)
p.WaitForExit()

herald('build/build-initial-image.bat')
runAndWait("build/build-initial-image.bat", runnable)



// Compile Scheme 48 VM to C code.

herald('build/generate-c-header.bat')
runAndWait('build/generate-c-header.bat', runnable)

herald('build/compile-vm.bat')
runAndWait('build/compile-vm.bat', runnable)

herald('build/compile-bibop-gc.bat')
runAndWait('build/compile-bibop-gc.bat', runnable)

// This isn't actually necessary, but it should be kept working for now.
herald('build/compile-twospace-gc.bat')
runAndWait('build/compile-twospace-gc.bat', runnable)

File.Copy('c/win32/scheme48arch.h', 'c/scheme48arch.h', true)



// Compile Scheme 48 VM to native code.

// TODO - find MSBuild.exe in a way that is more likely to work on other
//     developers' computers
herald('msbuild scheme48.sln')
runAndWait(
	"C:\\WINDOWS\\Microsoft.NET\\Framework\\v3.5\\MSBuild.exe",
	"/target:Rebuild",
	"/property:Configuration=Release",
	"/property:Platform=Win32",
	"scheme48.sln")



// Build the usual image.
//     The directory of this source tree will be hardcoded into the image.

cwdWithTrailingBackslash = Directory.GetCurrentDirectory()
unless cwdWithTrailingBackslash.EndsWith("\\"):
	cwdWithTrailingBackslash = cwdWithTrailingBackslash + "\\"

herald('build/build-usual-image.bat')
runAndWait(
	'build/build-usual-image.bat',
	cwdWithTrailingBackslash,
	cwdWithTrailingBackslash + "scheme",
	Directory.GetCurrentDirectory(),
	'scheme48.image',
	'scheme48vm.exe',
	'build/initial.image-32')



// Build the startup script.

herald('build/generate-go.bat')
runAndWait(
	'build/generate-go.bat',
	'scheme48.bat',
	"${cwdWithTrailingBackslash}scheme48vm.exe",
	"${cwdWithTrailingBackslash}scheme48.image")



// Run the test suite.
//     Not really necessary when building the system, but I've been burned
//     every time I skipped this part.

herald('build/check.bat')
runAndWait(
	'build/check.bat',
	'scheme48.bat')


