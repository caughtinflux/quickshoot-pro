#include <sys/types.h>
#include <sys/sysctl.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <ifaddrs.h>
#include <sys/socket.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <ifaddrs.h>
#import <mach/mach_host.h>
#import <mach/mach.h>

#if SUPPORTS_IOKIT_EXTENSIONS
#pragma mark IOKit miniheaders

#define kIODeviceTreePlane		"IODeviceTree"

enum {
    kIORegistryIterateRecursively	= 0x00000001,
    kIORegistryIterateParents		= 0x00000002
};

typedef mach_port_t	io_object_t;
typedef io_object_t	io_registry_entry_t;
typedef char		io_name_t[128];
typedef UInt32		IOOptionBits;

CFTypeRef
IORegistryEntrySearchCFProperty(
								io_registry_entry_t	entry,
								const io_name_t		plane,
								CFStringRef			key,
								CFAllocatorRef		allocator,
								IOOptionBits		options );

kern_return_t
IOMasterPort( mach_port_t	bootstrapPort,
			 mach_port_t *	masterPort );

io_registry_entry_t
IORegistryGetRootEntry(
					   mach_port_t	masterPort );

CFTypeRef
IORegistryEntrySearchCFProperty(
								io_registry_entry_t	entry,
								const io_name_t		plane,
								CFStringRef		key,
								CFAllocatorRef		allocator,
								IOOptionBits		options );

kern_return_t   mach_port_deallocate
(ipc_space_t                               task,
 mach_port_name_t                          name);

#endif
