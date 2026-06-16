// SPDX-License-Identifier: GPL-2.0
/* Copyright (c) 2023, SUSE. */

/* Minimal type definitions needed by bpf_helpers.h (instead of vmlinux.h) */
typedef unsigned char __u8;
typedef unsigned short __u16;
typedef unsigned int __u32;
typedef unsigned long long __u64;
typedef signed char __s8;
typedef signed short __s16;
typedef signed int __s32;
typedef signed long long __s64;
typedef __u16 __be16;
typedef __u32 __be32;
typedef __u64 __be64;
typedef __u32 __wsum;

enum bpf_map_type { __MAX_BPF_MAP_TYPE };
enum bpf_prog_type { __MAX_BPF_PROG_TYPE };
enum bpf_attach_type { __MAX_BPF_ATTACH_TYPE };

#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>

#define AF_INET       2
#define AF_INET6      10
#define SOCK_STREAM   1
#define IPPROTO_TCP   6
#define IPPROTO_MPTCP 262

char _license[] SEC("license") = "GPL";

SEC("fmod_ret/update_socket_protocol")
int BPF_PROG(mptcpify, int family, int type, int protocol)
{
	if ((family == AF_INET || family == AF_INET6) &&
	    type == SOCK_STREAM &&
	    (!protocol || protocol == IPPROTO_TCP)) {
		return IPPROTO_MPTCP;
	}

	return protocol;
}
