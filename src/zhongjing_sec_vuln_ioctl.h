/* SPDX-FileCopyrightText: 2026 Zhongjing Security Team */
/* SPDX-License-Identifier: LicenseRef-Zhongjing-Security-Proprietary */
#ifndef ZHONGJING_SEC_VULN_IOCTL_H
#define ZHONGJING_SEC_VULN_IOCTL_H

#ifdef __KERNEL__
#include <linux/ioctl.h>
#include <linux/types.h>
#else
typedef unsigned int __u32;
typedef unsigned long long __u64;
#ifndef _IOC
#define _IOC_NRBITS 8
#define _IOC_TYPEBITS 8
#define _IOC_SIZEBITS 14
#define _IOC_DIRBITS 2
#define _IOC_NRSHIFT 0
#define _IOC_TYPESHIFT (_IOC_NRSHIFT + _IOC_NRBITS)
#define _IOC_SIZESHIFT (_IOC_TYPESHIFT + _IOC_TYPEBITS)
#define _IOC_DIRSHIFT (_IOC_SIZESHIFT + _IOC_SIZEBITS)
#define _IOC_WRITE 1U
#define _IOC(dir, type, nr, size)   (((dir) << _IOC_DIRSHIFT) | ((type) << _IOC_TYPESHIFT) |    ((nr) << _IOC_NRSHIFT) | ((size) << _IOC_SIZESHIFT))
#define _IOW(type, nr, size) _IOC(_IOC_WRITE, (type), (nr), sizeof(size))
#endif
#endif

#define ZHONGJING_SEC_VULN_IOCTL_MAGIC 0xBA

struct zhongjing_sec_vuln_req {
  __u32 len;
  __u32 reserved;
  __u64 user_ptr;
};

#define ZHONGJING_SEC_VULN_IOCTL_TRIGGER   _IOW(ZHONGJING_SEC_VULN_IOCTL_MAGIC, 0x1, struct zhongjing_sec_vuln_req)

#endif
