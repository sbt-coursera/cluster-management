import sys
import subprocess
import xml.etree.ElementTree as ET

if len(sys.argv) != 2:
  print("Name of the auto-scaling group must be passed")
  sys.exit(1)

sp = subprocess.Popen("as-describe-auto-scaling-groups {0} --show-xml".format(sys.argv[1]), shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
out, err = sp.communicate()

if err:
	print "as-describe-auto-scaling-groups failed with error message"
	print err
	sys.exit(1)
if out == '':
	print "no output from as-describe-auto-scaling-groups"
	sys.exit(1)


try:
	data = ET.fromstring(out)
except:
	print "exception while parsing xml:"
	print out
	sys.exit(1)

namespace = data.tag[1:].split("}")[0]

try:
	res = int(data.find('./{0}DescribeAutoScalingGroupsResult/{0}AutoScalingGroups/{0}member/{0}DesiredCapacity'.format('{'+namespace+'}')).text)
except:
	print "exception while looking for DesiredCapacity"
	print out
	print sys.exc_info()[0]
	sys.exit(1)

print res
