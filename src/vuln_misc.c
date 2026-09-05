// SPDX-FileCopyrightText: 2026 Zhongjing Security Team
// SPDX-License-Identifier: LicenseRef-Zhongjing-Security-Proprietary
#include <linux/fs.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/miscdevice.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/uaccess.h>

#include "zhongjing_sec_vuln_ioctl.h"

#define ZHONGJING_SEC_BUF_SIZE 64U

static long zhongjing_sec_vuln_ioctl(struct file *file, unsigned int cmd,
                                unsigned long arg)
{
    struct zhongjing_sec_vuln_req req;
    unsigned int i;
    char *kbuf;
    char *ubuf;

    if (cmd != ZHONGJING_SEC_VULN_IOCTL_TRIGGER) {
        return -ENOTTY;
    }
    if (copy_from_user(&req, (void __user *)arg, sizeof(req)) != 0) {
        return -EFAULT;
    }
    if (req.len == 0 || req.user_ptr == 0) {
        return -EINVAL;
    }

    pr_info("zhongjing_sec_vuln_misc: requested copy len=%u user_ptr=0x%llx\n",
            req.len, (unsigned long long)req.user_ptr);

    ubuf = memdup_user(u64_to_user_ptr(req.user_ptr), req.len);
    if (IS_ERR(ubuf)) {
        return PTR_ERR(ubuf);
    }

    kbuf = kmalloc(ZHONGJING_SEC_BUF_SIZE, GFP_KERNEL);
    if (kbuf == NULL) {
        kfree(ubuf);
        return -ENOMEM;
    }
    memset(kbuf, 0x41, ZHONGJING_SEC_BUF_SIZE);

    for (i = 0; i < req.len; ++i) {
        kbuf[i] = ubuf[i];
    }

    pr_info("zhongjing_sec_vuln_misc: copy complete\n");
    kfree(kbuf);
    kfree(ubuf);
    return 0;
}

static const struct file_operations zhongjing_sec_vuln_fops = {
    .owner = THIS_MODULE,
    .unlocked_ioctl = zhongjing_sec_vuln_ioctl,
#ifdef CONFIG_COMPAT
    .compat_ioctl = zhongjing_sec_vuln_ioctl,
#endif
};

static struct miscdevice zhongjing_sec_vuln_miscdev = {
    .minor = MISC_DYNAMIC_MINOR,
    .name = "zhongjing-sec_misc",
    .fops = &zhongjing_sec_vuln_fops,
    .mode = 0666,
};

static int __init zhongjing_sec_vuln_init(void)
{
    int ret;

    ret = misc_register(&zhongjing_sec_vuln_miscdev);
    if (ret != 0) {
        return ret;
    }
    pr_info("zhongjing_sec_vuln_misc: registered /dev/%s with %u-byte heap buffer\n",
            zhongjing_sec_vuln_miscdev.name, ZHONGJING_SEC_BUF_SIZE);
    return 0;
}

static void __exit zhongjing_sec_vuln_exit(void)
{
    misc_deregister(&zhongjing_sec_vuln_miscdev);
    pr_info("zhongjing_sec_vuln_misc: unloaded\n");
}

module_init(zhongjing_sec_vuln_init);
module_exit(zhongjing_sec_vuln_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Zhongjing Security Team");
MODULE_DESCRIPTION("Deliberately vulnerable misc ioctl module for external PoC workflow examples");
