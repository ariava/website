---
layout: post
title:  "Quick debugging example feat. blktrace"
date:   2014-11-23 07:02:00
categories: blktrace block debugging ftrace kernel linux
---

I've been silent for more than two months now, and while I have been working on a post about deadlock debugging, and on my OPW patches (v2 thread [here](https://lkml.org/lkml/2014/9/11/1034)), and finishing up my last exams, and speaking at CloudOpen Europe (see [abstract](http://lccoelce14.sched.org/event/050c1a83ded7822e39e6ef0c644f0438), [slides](http://www.slideshare.net/xen_com_mgr/mb-os-q4-2014-proposal) - and also [pictures](https://drive.google.com/open?id=0B3VQ-C3TAxDFbVZCcWtiU3J4c0E&authuser=0), courtesy of [Lars Kurth](http://uk.linkedin.com/in/larskurth) and [Sven Jaborek](http://scholar.google.it/scholar?q=sven+jaborek)), and finally completing my Master's Degree (see me and my friends celebrating [here](https://drive.google.com/file/d/0B3VQ-C3TAxDFQV9aNXNmMVdfd1k/view?usp=sharing)), and thinking about what I want to do with my life - I also decided to try to upstream a very small bugfix patch I prepared for the Linux kernel's `blktrace` core. Before getting to the patch itself, I think it could be interesting - and not too long either - to explain the debugging process behind it. So, let's bore you with some kernel oops dissection!

A few months ago I was using the BFQ I/O scheduler's benchmark suite and I happened to stumble on the following kernel oops:

    [  117.383477] BUG: unable to handle kernel NULL pointer dereference at 0000000000000008
    [  117.391959] IP: [<ffffffff8112686b>] sysfs_blk_trace_attr_store+0x2ab/0x380
    [  117.399486] PGD 1aa7f4067 PUD 1aa7b8067 PMD 0
    [  117.399488] Oops: 0002 [#1] PREEMPT SMP
    [  117.399529] Modules linked in: bnep coretemp intel_powerclamp kvm_intel arc4 iwldvm kvm i915 mac80211 uvcvideo btusb crct10dif_pclmul bluetooth videobuf2_vmalloc videobuf2_memops crc32_pclmul crc32c_intel ghash_clmulni_intel videobuf2_core iwlwifi aesni_intel v4l2_common videodev snd_hda_codec_hdmi qcserial usb_wwan aes_x86_64 lrw snd_hda_codec_conexant ppdev usbserial iTCO_wdt gf128mul snd_hda_codec_generic mxm_wmi media glue_helper ablk_helper iTCO_vendor_support joydev cfg80211 snd_hda_intel mousedev cryptd snd_hda_controller snd_hda_codec drm_kms_helper psmouse microcode evdev e1000e pcspkr mac_hid drm snd_hwdep serio_raw intel_ips parport_pc thinkpad_acpi i2c_i801 snd_pcm tpm_tis mei_me nvram parport tpm thermal snd_timer rfkill shpchp mei snd intel_agp hwmon battery ptp lpc_ich wmi ac soundcore i2c_algo_bit i2c_core intel_gtt pps_core video button acpi_cpufreq sch_fq_codel processor hid_generic usbhid hid ext4 crc16 mbcache jbd2 ehci_pci ehci_hcd sd_mod ahci sdhci_pci libahci atkbd usbcore libps2 sdhci libata led_class firewire_ohci mmc_core firewire_core scsi_mod crc_itu_t usb_common i8042 serio
    [  117.399549] CPU: 1 PID: 520 Comm: tee Not tainted 3.18.0-rc5-rs232-test-kdump #190
    [  117.399550] Hardware name: LENOVO 2522WX8/2522WX8, BIOS 6IET85WW (1.45 ) 02/14/2013
    [  117.399551] task: ffff8800b6e65080 ti: ffff8801ab0f4000 task.ti: ffff8801ab0f4000
    [  117.399555] RIP: 0010:[<ffffffff8112686b>]  [<ffffffff8112686b>] sysfs_blk_trace_attr_store+0x2ab/0x380
    [  117.399556] RSP: 0018:ffff8801ab0f7df8  EFLAGS: 00010046
    [  117.399557] RAX: 0000000000000000 RBX: ffff8800b606c018 RCX: 0000000000000000
    [  117.399557] RDX: ffff8801ab0f7d98 RSI: ffff8800b6e65080 RDI: ffffffff8180a1c0
    [  117.399558] RBP: ffff8801ab0f7e68 R08: ffff8801ab0f4000 R09: ffff8801b5001700
    [  117.399559] R10: ffff8801bbc974e0 R11: ffffea0006c0bf40 R12: ffff8800b606c000
    [  117.399560] R13: 0000000000000002 R14: ffff8800b52c7500 R15: ffff880037928000
    [  117.399561] FS:  00007fd010cde700(0000) GS:ffff8801bbc80000(0000) knlGS:0000000000000000
    [  117.399562] CS:  0010 DS: 0000 ES: 0000 CR0: 000000008005003b
    [  117.399563] CR2: 0000000000000008 CR3: 00000001b073b000 CR4: 00000000000007e0
    [  117.399564] Stack:
    [  117.399566]  0000000000000001 0000000000000296 ffff8801ab0f7e48 ffff8801b05e6470
    [  117.399568]  ffffffff81095a30 0000000000000000 ffff8801b2b92c70 000000003d312879
    [  117.399569]  00007fff7a7e1f82 0000000000000002 ffff8801b0313790 ffff8800b52c7200
    [  117.399570] Call Trace:
    [  117.399576]  [<ffffffff81095a30>] ? wake_up_process+0x50/0x50
    [  117.399582]  [<ffffffff813accc8>] dev_attr_store+0x18/0x30
    [  117.399588]  [<ffffffff8123ee8a>] sysfs_kf_write+0x3a/0x50
    [  117.399590]  [<ffffffff8123e3ce>] kernfs_fop_write+0xee/0x180
    [  117.399594]  [<ffffffff811c63a7>] vfs_write+0xb7/0x200
    [  117.399596]  [<ffffffff811c62b4>] ? vfs_read+0x144/0x180
    [  117.399598]  [<ffffffff811c6ef9>] SyS_write+0x59/0xd0
    [  117.399603]  [<ffffffff8154bf69>] system_call_fastpath+0x12/0x17
    [  117.399620] Code: 00 00 00 f0 ff 0d ce 10 9d 00 0f 84 c2 00 00 00 48 c7 c7 c0 a1 80 81 e8 64 4c 42 00 49 8b 4e 58 49 8b 46 60 48 c7 c7 c0 a1 80 81 <48> 89 41 08 48 89 08 48 b8 00 01 10 00 00 00 ad de 49 89 46 58 
    [  117.399622] RIP  [<ffffffff8112686b>] sysfs_blk_trace_attr_store+0x2ab/0x380
    [  117.399623]  RSP <ffff8801ab0f7df8>
    [  117.399624] CR2: 0000000000000008
    [  117.399626] ---[ end trace b0bf4bf2fac3d64a ]---
    [  117.399628] note: tee[520] exited with preempt_count 1

After a few steps of narrowing the reproducer down, I could establish that it was the sequence of the following two simple bash commands:

    # echo 1 > /sys/block/sda/trace/enable
    # echo 0 > /sys/block/sda/trace/enable

To be even more minimal in explaining it, the action triggering the kernel oops was stopping a block trace. After glaring in disappointment to the pesky oops for some time, I finally decided to try to investigate it. After considering bisecting it for a while, I decided to just call out to `gdb` for help. I fortunately was running a custom kernel with debugging symbols compiled in it, so I didn't have to run through the process I described in a [previous post](http://ari-ava.blogspot.it/2014/08/opw-linux-hunting-bugs-with-oopses.html).

    $ gdb vmlinux
    GNU gdb (GDB) 7.8.1
    Copyright (C) 2014 Free Software Foundation, Inc.
    <snip>
    Reading symbols from vmlinux...done.
    **(gdb) l *(sysfs_blk_trace_attr_store+0x2ab)**
    0xffffffff8112686b is in sysfs_blk_trace_attr_store (include/linux/list.h:89).
    84       * This is only for internal list manipulation where we know
    85       * the prev/next entries already!
    86       */
    87      static inline void __list_del(struct list_head * prev, struct list_head * next)
    88      {
    89              next->prev = prev;
    90              prev->next = next;
    91      }
    92
    93      /**
    (gdb)

Well, not much help, `gdb`. That's pretty generic. The crashing point is a null pointer dereference happening into a list handling function inlined into the `blk_trace_attr_store()` `blktrace` function. Let's have a look to the `blktrace` function to see if it handles lists somewhere. Now, we probably can find it inside the `blktrace` core, which resides in `kernel/trace/blktrace.c`, but let's pretend we don't even know where the ifunction is and let's see how we can find it out. Solution 1 - the simplest: `grep` it and hope for the best. We're lazy and we don't want to wait for the output to eventually appear. Solution 2 - use `cscope`, an efficient utility to explore C source files. With

    $ cscope -R

we simply ask `cscope` to index all C files (and related headers) in the current directory and all its subdirectories. Finally, we are prompted with a text-based interface that includes a bunch of functionalities and, most importantly, allows us to search for all definitions of a symbol. Just what we need. Eventually, we find the source code of the `blk_trace_attr_store()` `blktrace` function, but it seems not to help either. It's very long and does not handle lists by itself. Fortunately, by examining the code, we can see it is quite simple to follow. More in detail, we know that the issue happens when we stop a block trace, so practically when we set to 0 the `/sys/block/sdX/trace/enable` tunable for a block device. Now, let's have a look to this piece of code from the `blk_trace_attr_store()` function:

    if (attr == &dev_attr_enable) {
            if (value)
                    ret = blk_trace_setup_queue(q, bdev);
            else
                    ret = blk_trace_remove_queue(q);
            goto out_unlock_bdev;
    }

So, just to explain what it means: if we're triggering an action with the tunable representing the trace enabler, then: if the value we're setting is true (1), we call `blk_trace_setup_queue()`, else we call `blk_trace_remove_queue()`. Then we unlock the device. Seems like the next function we're going to look at is `blk_trace_remove_queue()`! And it also seems it's shorter, woot! And it handles a list, woot woot!

    static int blk_trace_remove_queue(struct request_queue *q)
    {
            struct blk_trace *bt;
    
            bt = xchg(&q->blk_trace, NULL);
            if (bt == NULL)
                    return -EINVAL;
    
            if (atomic_dec_and_test(&blk_probes_ref))
                    blk_unregister_tracepoints();
    
            spin_lock_irq(&running_trace_lock);
            list_del(&bt->running_list);
            spin_unlock_irq(&running_trace_lock);
            blk_trace_free(bt);
            return 0;
    }

The point where the function handles lists concerns the removal of a block trace from a list keeping pointers to all running traces. Makes sense. Let's see where the insertion happens. It seems that the only invocation of `list_add(&bt->running_list, &running_trace_list)` is in the `blk_trace_startstop()` function. It's pretty weird, because the only invocation of the latter we can find in `blktrace.c` happens as a result of some action issued with the ioctl-based interface exposed by `blktrace`. This probably means that, when we use the sysfs tunable and we set it to 1, the trace is not inserted at all in the running list. By looking at the code we can also see that, when a trace is added to the running trace list, the state of the trace is changed to `Blktrace_running`. Also, when the list is removed from the list in `blk_trace_startstop()`, it is removed only if its state is `Blktrace_running`.

As a proof of concept, we can try to mimic what happens in `blk_trace_startstop()` by replicating it in `blk_trace_remove_queue()` (as in the [first version](https://lkml.org/lkml/2014/11/8/80) I proposed on lkml):

    kernel/trace/blktrace.c | 8 +++++---
    1 file changed, 5 insertions(+), 3 deletions(-)
    diff --git a/kernel/trace/blktrace.c b/kernel/trace/blktrace.c
    index c1bd4ad..f58b617 100644
    --- a/kernel/trace/blktrace.c
    +++ b/kernel/trace/blktrace.c
    @@ -1493,9 +1493,11 @@ static int blk_trace_remove_queue(struct request_queue *q)
      if (atomic_dec_and_test(&blk_probes_ref))
             blk_unregister_tracepoints();
     
    - spin_lock_irq(&running_trace_lock);
    - list_del(&bt->running_list);
    - spin_unlock_irq(&running_trace_lock);
    + if (bt->trace_state == Blktrace_running) {
    +         spin_lock_irq(&running_trace_lock);
    +         list_del(&bt->running_list);
    +         spin_unlock_irq(&running_trace_lock);
    + }
      blk_trace_free(bt);
      return 0;
     }

Actually, even if the patch reached its goal, this is an inefficient solution, as it turns out that the running trace list is reserved to the ioctl-based interface and as such it should not be ever touched by the sysfs-based interface. As Namhyung Kim [noted](https://lkml.org/lkml/2014/11/10/99) that, I proposed a [second version](https://lkml.org/lkml/2014/11/10/196) of the patch, which is even smaller.

    kernel/trace/blktrace.c | 3 ---
    1 file changed, 3 deletions(-)
    diff --git a/kernel/trace/blktrace.c b/kernel/trace/blktrace.c
    index c1bd4ad..bd05fd2 100644
    --- a/kernel/trace/blktrace.c
    +++ b/kernel/trace/blktrace.c
    @@ -1493,9 +1493,6 @@ static int blk_trace_remove_queue(struct request_queue *q)
      if (atomic_dec_and_test(&blk_probes_ref))
          blk_unregister_tracepoints();
     
    - spin_lock_irq(&running_trace_lock);
    - list_del(&bt->running_list);
    - spin_unlock_irq(&running_trace_lock);
      blk_trace_free(bt);
      return 0;
     }
