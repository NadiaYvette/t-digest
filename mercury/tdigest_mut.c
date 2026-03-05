/*
** Automatically generated from `tdigest_mut.m'
** by the Mercury compiler,
** version rotd-2024-06-15
** configured for x86_64-pc-linux-gnu.
** Do not edit.
**
** The autoconfigured grade settings governing
** the generation of this C file were
**
** TAG_BITS=3
** UNBOXED_FLOAT=yes
** UNBOXED_INT64S=yes
** PREGENERATED_DIST=no
** HIGHLEVEL_CODE=no
**
** END_OF_C_GRADE_INFO
*/

/*
INIT mercury__tdigest_mut__init
ENDINIT
*/

#define MR_ALLOW_RESET
#include "mercury_imp.h"
#line 28 "tdigest_mut.c"
#include "array.mh"

#line 31 "tdigest_mut.c"
#line 32 "tdigest_mut.c"
#include "tdigest_mut.mh"

#line 35 "tdigest_mut.c"
#line 36 "tdigest_mut.c"
#ifndef TDIGEST_MUT_DECL_GUARD
#define TDIGEST_MUT_DECL_GUARD

#line 40 "tdigest_mut.c"
#line 41 "tdigest_mut.c"

#endif
#line 44 "tdigest_mut.c"

#ifdef _MSC_VER
#define MR_STATIC_LINKAGE extern
#else
#define MR_STATIC_LINKAGE static
#endif
MR_decl_label2(tdigest_mut__cdf_4_0, 2,3)
MR_decl_label2(tdigest_mut__centroid_count_3_0, 2,3)
MR_decl_label2(tdigest_mut__quantile_4_0, 2,3)
MR_def_extern_entry(tdigest_mut__add_3_0)
MR_def_extern_entry(tdigest_mut__add_weighted_4_0)
MR_def_extern_entry(tdigest_mut__compress_2_0)
MR_def_extern_entry(tdigest_mut__quantile_4_0)
MR_def_extern_entry(tdigest_mut__cdf_4_0)
MR_def_extern_entry(tdigest_mut__merge_3_0)
MR_def_extern_entry(tdigest_mut__centroid_count_3_0)



MR_decl_entry(fn__tdigest__add_value_2_0);

MR_BEGIN_MODULE(tdigest_mut_module0)
	MR_init_entry1(tdigest_mut__add_3_0);
	MR_INIT_PROC_LAYOUT_ADDR(mercury__tdigest_mut__add_3_0);
MR_BEGIN_CODE

/*-------------------------------------------------------------------------*/
/* code for pred 'add'/3 mode 0 */
#ifdef MR_maybe_local_thread_engine_base
	#undef MR_maybe_local_thread_engine_base
	#define MR_maybe_local_thread_engine_base MR_local_thread_engine_base
#endif
MR_define_entry(mercury__tdigest_mut__add_3_0);
	MR_MAYBE_INIT_LOCAL_THREAD_ENGINE_BASE
	MR_np_tailcall_ent(fn__tdigest__add_value_2_0);
#ifdef MR_maybe_local_thread_engine_base
	#undef MR_maybe_local_thread_engine_base
	#define MR_maybe_local_thread_engine_base MR_thread_engine_base
#endif
MR_END_MODULE

MR_decl_entry(fn__tdigest__add_3_0);

MR_BEGIN_MODULE(tdigest_mut_module1)
	MR_init_entry1(tdigest_mut__add_weighted_4_0);
	MR_INIT_PROC_LAYOUT_ADDR(mercury__tdigest_mut__add_weighted_4_0);
MR_BEGIN_CODE

/*-------------------------------------------------------------------------*/
/* code for pred 'add_weighted'/4 mode 0 */
#ifdef MR_maybe_local_thread_engine_base
	#undef MR_maybe_local_thread_engine_base
	#define MR_maybe_local_thread_engine_base MR_local_thread_engine_base
#endif
MR_define_entry(mercury__tdigest_mut__add_weighted_4_0);
	MR_MAYBE_INIT_LOCAL_THREAD_ENGINE_BASE
	{
	MR_Word MR_tempr1, MR_tempr2;
	MR_tempr1 = MR_r1;
	MR_r1 = MR_r3;
	MR_tempr2 = MR_r2;
	MR_r2 = MR_tempr1;
	MR_r3 = MR_tempr2;
	MR_np_tailcall_ent(fn__tdigest__add_3_0);
	}
#ifdef MR_maybe_local_thread_engine_base
	#undef MR_maybe_local_thread_engine_base
	#define MR_maybe_local_thread_engine_base MR_thread_engine_base
#endif
MR_END_MODULE

MR_decl_entry(fn__tdigest__compress_1_0);

MR_BEGIN_MODULE(tdigest_mut_module2)
	MR_init_entry1(tdigest_mut__compress_2_0);
	MR_INIT_PROC_LAYOUT_ADDR(mercury__tdigest_mut__compress_2_0);
MR_BEGIN_CODE

/*-------------------------------------------------------------------------*/
/* code for pred 'compress'/2 mode 0 */
#ifdef MR_maybe_local_thread_engine_base
	#undef MR_maybe_local_thread_engine_base
	#define MR_maybe_local_thread_engine_base MR_local_thread_engine_base
#endif
MR_define_entry(mercury__tdigest_mut__compress_2_0);
	MR_MAYBE_INIT_LOCAL_THREAD_ENGINE_BASE
	MR_np_tailcall_ent(fn__tdigest__compress_1_0);
#ifdef MR_maybe_local_thread_engine_base
	#undef MR_maybe_local_thread_engine_base
	#define MR_maybe_local_thread_engine_base MR_thread_engine_base
#endif
MR_END_MODULE

MR_decl_entry(fn__tdigest__ensure_compressed_1_0);
MR_decl_entry(fn__tdigest__quantile_2_0);

MR_BEGIN_MODULE(tdigest_mut_module3)
	MR_init_entry1(tdigest_mut__quantile_4_0);
	MR_INIT_PROC_LAYOUT_ADDR(mercury__tdigest_mut__quantile_4_0);
	MR_init_label2(tdigest_mut__quantile_4_0, 2,3)
MR_BEGIN_CODE

/*-------------------------------------------------------------------------*/
/* code for pred 'quantile'/4 mode 0 */
#ifdef MR_maybe_local_thread_engine_base
	#undef MR_maybe_local_thread_engine_base
	#define MR_maybe_local_thread_engine_base MR_local_thread_engine_base
#endif
MR_define_entry(mercury__tdigest_mut__quantile_4_0);
	MR_MAYBE_INIT_LOCAL_THREAD_ENGINE_BASE
	MR_incr_sp(2);
	MR_sv(2) = ((MR_Word) MR_succip);
	MR_sv(1) = MR_r1;
	MR_r1 = MR_r2;
	MR_np_call_localret_ent(fn__tdigest__ensure_compressed_1_0,
		tdigest_mut__quantile_4_0_i2);
MR_def_label(tdigest_mut__quantile_4_0, 2)
	MR_MAYBE_INIT_LOCAL_THREAD_ENGINE_BASE
	{
	MR_Word MR_tempr1;
	MR_tempr1 = MR_sv(1);
	MR_sv(1) = MR_r1;
	MR_r2 = MR_tempr1;
	}
	MR_np_call_localret_ent(fn__tdigest__quantile_2_0,
		tdigest_mut__quantile_4_0_i3);
MR_def_label(tdigest_mut__quantile_4_0, 3)
	MR_MAYBE_INIT_LOCAL_THREAD_ENGINE_BASE
	{
	MR_Word MR_tempr1;
	MR_tempr1 = MR_r1;
	MR_r1 = MR_sv(1);
	MR_r2 = MR_tempr1;
	MR_decr_sp_and_return(2);
	}
#ifdef MR_maybe_local_thread_engine_base
	#undef MR_maybe_local_thread_engine_base
	#define MR_maybe_local_thread_engine_base MR_thread_engine_base
#endif
MR_END_MODULE

MR_decl_entry(fn__tdigest__cdf_2_0);

MR_BEGIN_MODULE(tdigest_mut_module4)
	MR_init_entry1(tdigest_mut__cdf_4_0);
	MR_INIT_PROC_LAYOUT_ADDR(mercury__tdigest_mut__cdf_4_0);
	MR_init_label2(tdigest_mut__cdf_4_0, 2,3)
MR_BEGIN_CODE

/*-------------------------------------------------------------------------*/
/* code for pred 'cdf'/4 mode 0 */
#ifdef MR_maybe_local_thread_engine_base
	#undef MR_maybe_local_thread_engine_base
	#define MR_maybe_local_thread_engine_base MR_local_thread_engine_base
#endif
MR_define_entry(mercury__tdigest_mut__cdf_4_0);
	MR_MAYBE_INIT_LOCAL_THREAD_ENGINE_BASE
	MR_incr_sp(2);
	MR_sv(2) = ((MR_Word) MR_succip);
	MR_sv(1) = MR_r1;
	MR_r1 = MR_r2;
	MR_np_call_localret_ent(fn__tdigest__ensure_compressed_1_0,
		tdigest_mut__cdf_4_0_i2);
MR_def_label(tdigest_mut__cdf_4_0, 2)
	MR_MAYBE_INIT_LOCAL_THREAD_ENGINE_BASE
	{
	MR_Word MR_tempr1;
	MR_tempr1 = MR_sv(1);
	MR_sv(1) = MR_r1;
	MR_r2 = MR_tempr1;
	}
	MR_np_call_localret_ent(fn__tdigest__cdf_2_0,
		tdigest_mut__cdf_4_0_i3);
MR_def_label(tdigest_mut__cdf_4_0, 3)
	MR_MAYBE_INIT_LOCAL_THREAD_ENGINE_BASE
	{
	MR_Word MR_tempr1;
	MR_tempr1 = MR_r1;
	MR_r1 = MR_sv(1);
	MR_r2 = MR_tempr1;
	MR_decr_sp_and_return(2);
	}
#ifdef MR_maybe_local_thread_engine_base
	#undef MR_maybe_local_thread_engine_base
	#define MR_maybe_local_thread_engine_base MR_thread_engine_base
#endif
MR_END_MODULE

MR_decl_entry(fn__tdigest__merge_digests_2_0);

MR_BEGIN_MODULE(tdigest_mut_module5)
	MR_init_entry1(tdigest_mut__merge_3_0);
	MR_INIT_PROC_LAYOUT_ADDR(mercury__tdigest_mut__merge_3_0);
MR_BEGIN_CODE

/*-------------------------------------------------------------------------*/
/* code for pred 'merge'/3 mode 0 */
#ifdef MR_maybe_local_thread_engine_base
	#undef MR_maybe_local_thread_engine_base
	#define MR_maybe_local_thread_engine_base MR_local_thread_engine_base
#endif
MR_define_entry(mercury__tdigest_mut__merge_3_0);
	MR_MAYBE_INIT_LOCAL_THREAD_ENGINE_BASE
	{
	MR_Word MR_tempr1;
	MR_tempr1 = MR_r1;
	MR_r1 = MR_r2;
	MR_r2 = MR_tempr1;
	MR_np_tailcall_ent(fn__tdigest__merge_digests_2_0);
	}
#ifdef MR_maybe_local_thread_engine_base
	#undef MR_maybe_local_thread_engine_base
	#define MR_maybe_local_thread_engine_base MR_thread_engine_base
#endif
MR_END_MODULE

MR_decl_entry(fn__tdigest__centroid_count_1_0);

MR_BEGIN_MODULE(tdigest_mut_module6)
	MR_init_entry1(tdigest_mut__centroid_count_3_0);
	MR_INIT_PROC_LAYOUT_ADDR(mercury__tdigest_mut__centroid_count_3_0);
	MR_init_label2(tdigest_mut__centroid_count_3_0, 2,3)
MR_BEGIN_CODE

/*-------------------------------------------------------------------------*/
/* code for pred 'centroid_count'/3 mode 0 */
#ifdef MR_maybe_local_thread_engine_base
	#undef MR_maybe_local_thread_engine_base
	#define MR_maybe_local_thread_engine_base MR_local_thread_engine_base
#endif
MR_define_entry(mercury__tdigest_mut__centroid_count_3_0);
	MR_MAYBE_INIT_LOCAL_THREAD_ENGINE_BASE
	MR_incr_sp(2);
	MR_sv(2) = ((MR_Word) MR_succip);
	MR_np_call_localret_ent(fn__tdigest__ensure_compressed_1_0,
		tdigest_mut__centroid_count_3_0_i2);
MR_def_label(tdigest_mut__centroid_count_3_0, 2)
	MR_MAYBE_INIT_LOCAL_THREAD_ENGINE_BASE
	MR_sv(1) = MR_r1;
	MR_np_call_localret_ent(fn__tdigest__centroid_count_1_0,
		tdigest_mut__centroid_count_3_0_i3);
MR_def_label(tdigest_mut__centroid_count_3_0, 3)
	MR_MAYBE_INIT_LOCAL_THREAD_ENGINE_BASE
	{
	MR_Word MR_tempr1;
	MR_tempr1 = MR_r1;
	MR_r1 = MR_sv(1);
	MR_r2 = MR_tempr1;
	MR_decr_sp_and_return(2);
	}
#ifdef MR_maybe_local_thread_engine_base
	#undef MR_maybe_local_thread_engine_base
	#define MR_maybe_local_thread_engine_base MR_thread_engine_base
#endif
MR_END_MODULE

static void mercury__tdigest_mut_maybe_bunch_0(void)
{
	tdigest_mut_module0();
	tdigest_mut_module1();
	tdigest_mut_module2();
	tdigest_mut_module3();
	tdigest_mut_module4();
	tdigest_mut_module5();
	tdigest_mut_module6();
}

/* suppress gcc -Wmissing-decls warnings */
void mercury__tdigest_mut__init(void);
void mercury__tdigest_mut__init_type_tables(void);
void mercury__tdigest_mut__init_debugger(void);
#ifdef MR_DEEP_PROFILING
void mercury__tdigest_mut__write_out_proc_statics(FILE *deep_fp, FILE *procrep_fp);
#endif
#ifdef MR_RECORD_TERM_SIZES
void mercury__tdigest_mut__init_complexity_procs(void);
#endif
#ifdef MR_THREADSCOPE
void mercury__tdigest_mut__init_threadscope_string_table(void);
#endif
const char *mercury__tdigest_mut__grade_check(void);

void mercury__tdigest_mut__init(void)
{
	static MR_bool done = MR_FALSE;
	if (done) {
		return;
	}
	done = MR_TRUE;
	mercury__tdigest_mut_maybe_bunch_0();
	mercury__tdigest_mut__init_debugger();
}

void mercury__tdigest_mut__init_type_tables(void)
{
	static MR_bool done = MR_FALSE;
	if (done) {
		return;
	}
	done = MR_TRUE;
}


void mercury__tdigest_mut__init_debugger(void)
{
	static MR_bool done = MR_FALSE;
	if (done) {
		return;
	}
	done = MR_TRUE;
}

#ifdef MR_DEEP_PROFILING

void mercury__tdigest_mut__write_out_proc_statics(FILE *deep_fp, FILE *procrep_fp)
{
	MR_write_out_module_proc_reps_start(procrep_fp, &mercury_data__module_layout__tdigest_mut);
	MR_write_out_module_proc_reps_end(procrep_fp);
}

#endif

#ifdef MR_RECORD_TERM_SIZES

void mercury__tdigest_mut__init_complexity_procs(void)
{
}

#endif

#ifdef MR_THREADSCOPE

void mercury__tdigest_mut__init_threadscope_string_table(void)
{
}

#endif

// Ensure everything is compiled with the same grade.
const char *mercury__tdigest_mut__grade_check(void)
{
    return &MR_GRADE_VAR;
}
