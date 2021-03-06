% SECD verification                                                 %
%                                                                   %
% FILE:         correctness_LD.ml                                   %
%                                                                   %
% DESCRIPTION:  The correspondence between the specification for    % 
%               LD instruction, and the computational effect of     %
%               the machine executing an LD instruction.            %
%                                                                   %
% USES FILES:   correctness_misc.th, wordn & integer libraries      %
%               liveness - only to get at ancestor theories ...     %
%                                                                   %
% Brian Graham 06.12.90                                             %
%                                                                   %
% Modifications:                                                    %
% 09.08.91 - BtG - updated to HOL2                                  %
% ================================================================= %
new_theory `correctness_LD`;;

map new_parent
 [ `correctness_misc`
 ; `liveness`
 ];;

loadf `wordn`;;
load_library `integer`;;

map (load_theorem `correctness_misc`)
 [ `LET_THM`
 ; `Store14_root_1_lemma`
 ; `Store14_car_cdr_1_lemma`
 ; `LD_opcode_lemma`
 ];;

map (load_definition `when`)
 [ `when`
 ];;
map (load_theorem `when`)
 [ `TimeOf_Next_lemma`
 ];;

map (load_definition `constraints`)
 [ `reserved_words_constraint`
 ];;
map (load_theorem `constraints`)
 [ `state_abs_thm`
 ; `well_formed_free_list_lemma`
 ; `well_formed_free_list_nonintersection_lemma`
 ];;
map (load_definition `top_SECD`)
 [ `LD_trans`
 ; `cell_of`
 ; `mem_free_of`
 ; `mem_of`
 ; `free_of`
 ];;
map (load_theorem `mu-prog_LD`)
 [ `LD_state`
 ; `LD_Next`
 ];;
map (load_definition `abstract_mem_type`)
 [ `M_CAR`
 ; `M_CDR`
 ; `M_Cons_tr`
 ];;
map (load_theorem `mem_abs`)
 [ `car_cdr_mem_abs_lemma`
 ; `M_Cons_unfold_1_thm`
 ; `number_mem_abs_lemma`
 ];;
load_definition `top_SECD` `nth` ;;
% ================================================================= %
let mtime = ":num"
and ctime = ":num";;
let w14_mvec = ":^mtime->word14";;

let mem14_32 = ":word14->word32";;
let m14_32_mvec = ":^mtime->^mem14_32";;
let M = ":(word14,atom)mfsexp_mem";;
let M_mvec = ":^mtime->^M";;

let state = ":bool # bool";;
let state_msig = ":^mtime->^state"
and state_csig = ":^ctime->^state";;

% ================================================================= %
% This defines a relation on the inputs and outputs.                %
% ================================================================= %
let SYS_imp = (hd o tl o hyp)(theorem `phase_lemmas1` `phase_lemma_0`);;

% ================================================================= %
loadt `ABBREV_TAC`;;

% ================================================================= %
timer true;;

% ================================================================= %
% Discharge every assumption with "t" in it, and generalize it.     %
% ================================================================= %
let LD_state' =
 GEN "t:^mtime"
 (itlist DISCH (filter (free_in "t:num") (hyp LD_state)) LD_state);;
let LD_Next' =
 GEN "t:^mtime" 
   (itlist DISCH (filter (free_in "t:num") (hyp LD_Next)) LD_Next);;

% ================================================================= %
% Theorems/lemmas needed for the loop special case:                 %
% ================================================================= %
% ================================================================= %
let l1 = prove
("!n.(!n'. n' <= (SUC n) ==> is_cons(nth n'(memory o cdr_bits)(memory x))) ==>
    (!n'. n' <= n ==> is_cons(nth n'(memory o cdr_bits)(memory x)))",
 GEN_TAC
 THEN DISCH_THEN
 (\th. GEN_TAC
  THEN STRIP_TAC
  THEN MATCH_MP_TAC th)
 THEN MATCH_MP_TAC (SPECL ["n':num"; "n:num"; "SUC n"] LESS_EQ_TRANS)
 THEN art[LESS_EQ_SUC_REFL]
 );;

% ================================================================= %
let l2 = prove
("!n. nth n (memory o cdr_bits)(memory x) = memory(nth n (cdr_bits o memory)x)",
 INDUCT_TAC
 THEN port[nth]
 THENL
 [ REFL_TAC
 ; art[o_THM]
 ]);;

% ================================================================= %
let nth_cdr_lemma = prove
("!n.
  (!n'. (n' <= n) ==> is_cons(nth n' (memory o cdr_bits) (memory x))) ==>
      (nth n M_CDR (x, mem_abs memory, z) =
       (nth n (cdr_bits o memory)x, mem_abs memory, z))",
 INDUCT_TAC
 THENL
 [ rt[nth]
 ; DISCH_THEN (\th. STRIP_ASSUME_TAC (rr[nth; o_THM; LESS_EQ_SUC_REFL](SPEC "n:num" th))
                    THEN ASSUME_TAC th)
   THEN IMP_RES_THEN (ANTE_RES_THEN ASSUME_TAC)l1
   THEN art[M_CDR; nth; o_THM]
   THEN IMP_RES_TAC(AP_TERM "is_cons"(SPEC "n:num" l2))
   THEN IMP_RES_THEN port1 car_cdr_mem_abs_lemma
   THEN REFL_TAC
 ]);;

% ================================================================= %
let car_nth_cdr_lemma = prove
("!n.
  (!n'. (n' <= n) ==> is_cons(nth n' (memory o cdr_bits) (memory x))) ==>
      (M_CAR(nth n M_CDR (x, mem_abs memory, z)) =
       (car_bits(memory(nth n (cdr_bits o memory)x))), mem_abs memory, z)",
 GEN_TAC
 THEN DISCH_THEN (\th. (ASSUME_TAC o (rr[LESS_EQ_REFL]) o (SPEC "n:num"))th
		       THEN (port1 (MATCH_MP nth_cdr_lemma th)))
 THEN port[M_CAR]
 THEN IMP_RES_TAC(AP_TERM "is_cons"(SPEC "n:num" l2))
 THEN IMP_RES_THEN port1 car_cdr_mem_abs_lemma
 THEN REFL_TAC
 );;

% ================================================================= %
let DEC28_assum1 =
"!w28. (POS (iVal (Bits28 w28)))==>
        (PRE(pos_num_of(iVal(Bits28 w28))) =
           pos_num_of(iVal(Bits28((atom_bits o DEC28) w28))))"
and DEC28_assum2 =
"!w28.(POS (iVal (Bits28 w28)))==>
     ~(NEG (iVal (Bits28 ((atom_bits o DEC28) w28))))";;

% ================================================================= %
% Correctness goal for the LD instruction.                          %
% ================================================================= %
let correctness_LD = TAC_PROOF
(([
   % -----------------------------  %
   "!n'. (n' <= (pos_num_of n)) ==>
        (is_cons (nth n' ((memory(TimeOf(is_major_state mpc)t)) o cdr_bits)
                      (memory(TimeOf(is_major_state mpc)t)
                             (car_bits
                                (nth (pos_num_of m)
                                     ((memory(TimeOf(is_major_state mpc)t))
                                      o cdr_bits)
                                     (memory(TimeOf(is_major_state mpc)t)
                                            (e(TimeOf(is_major_state mpc)t)))))
                      )))"
 ; % -----------------------------  %
   "!m'. (m' <= (pos_num_of m)) ==>
        (is_cons (nth m' ((memory(TimeOf(is_major_state mpc)t)) o cdr_bits)
                      (memory(TimeOf(is_major_state mpc)t)
                             (e(TimeOf(is_major_state mpc)t)))))"
 ; % -----------------------------  %
   "~(NEG n)"
 ; % -----------------------------  %
   "~(NEG m)"
 ; % ----------------------------- abbreviate iVal(... mem(cdadr c)) %
   "n = iVal(Bits28(atom_bits n_cell))"
 ; % ----------------------------- abbreviate iVal(... mem(caadr c)) %
   "m = iVal(Bits28(atom_bits m_cell))"
 ; % ----------------------------- (cdadr c) is a number %
   "is_number n_cell"
 ; % ----------------------------- (caadr c) is a number %
   "is_number m_cell"
 ; % ----------------------------- abbreviate (mem (cdadr c)) %
   "(n_cell:word32) = (memory(TimeOf(is_major_state mpc)t) (cdr_bits arg_cons_cell))"
 ; % ----------------------------- abbreviate (mem (caadr c)) %
   "(m_cell:word32) = (memory(TimeOf(is_major_state mpc)t) (car_bits arg_cons_cell))"
 ; % ----------------------------- (cadr c) is an cons %
   "is_cons arg_cons_cell"
 ; % ----------------------------- abbreviate (mem (cadr c)) %
   "arg_cons_cell =
              (memory(TimeOf(is_major_state mpc)t)
               (car_bits(memory(TimeOf(is_major_state mpc)t)
                (cdr_bits(memory(TimeOf(is_major_state mpc)t)
                         ((c:^w14_mvec)(TimeOf(is_major_state mpc)t)))))))"
 ; % ----------------------------- (cdr c) is a cons cell %
   "is_cons(memory(TimeOf(is_major_state mpc)t)
            (cdr_bits(memory(TimeOf(is_major_state mpc)t)
                     ((c:^w14_mvec)(TimeOf(is_major_state mpc)t)))))"
 ; % ----------------------------- DEC28 assumptions %
   DEC28_assum1
 ; DEC28_assum2
 ; % ----------------------------- the opcode is LD %
   "atom_bits(memory(TimeOf(is_major_state mpc)t)
            (car_bits(memory(TimeOf(is_major_state mpc)t)
                      ((c:^w14_mvec)(TimeOf(is_major_state mpc)t))))) =
    #0000000000000000000000000001" 
 ; % ----------------------------- opcode is a number record %
   "is_number(memory(TimeOf(is_major_state mpc)t)
              (car_bits(memory(TimeOf(is_major_state mpc)t)
                        ((c:^w14_mvec)(TimeOf(is_major_state mpc)t)))))"
 ; % ----------------------------- c is itself a cons cell %
   "is_cons(memory(TimeOf(is_major_state mpc)t)
            ((c:^w14_mvec)(TimeOf(is_major_state mpc)t)))"
 ; "mpc(TimeOf(is_major_state mpc)t) = #000101011" 
 ; "Inf(is_major_state mpc)"
 ; "well_formed_free_list memory mpc free s e c d"
 ; "reserved_words_constraint mpc memory" 
 ; SYS_imp
 ; "clock_constraint SYS_Clocked" 
 ],
 "((s                  when (is_major_state mpc))(SUC t),    
    (e                  when (is_major_state mpc))(SUC t),
    (c                  when (is_major_state mpc))(SUC t),
    (d                  when (is_major_state mpc))(SUC t),
    (free               when (is_major_state mpc))(SUC t), 
    ((mem_abs o memory) when (is_major_state mpc))(SUC t), 
    ((state_abs o mpc)  when (is_major_state mpc))(SUC t)) =
    LD_trans ((s                  when (is_major_state mpc))t,
               (e                  when (is_major_state mpc))t,
               (c                  when (is_major_state mpc))t,
               (d                  when (is_major_state mpc))t,
               (free               when (is_major_state mpc))t,
               ((mem_abs o memory) when (is_major_state mpc))t)
 "),
 FIRST_ASSUM (\th. "$= (arg_cons_cell:word32)" = fst(dest_comb(concl th))
    => SUBST_ALL_TAC th
     | NO_TAC)
 THEN EVERY_ASSUM (\th. ("$= (m_cell:word32)" = fst(dest_comb(concl th)) or
                            "$= (n_cell:word32)" = fst(dest_comb(concl th)))
    => SUBST_ALL_TAC th
     | ALL_TAC)
 THEN EVERY_ASSUM (\th. ("$= (m:integer)" = fst(dest_comb(concl th)) or
                            "$= (n:integer)" = fst(dest_comb(concl th)))
    => SUBST_ALL_TAC th
     | ALL_TAC)
 THEN RULE_ASSUM_TAC(prr[(GEN_ALL o EQT_INTRO o SPEC_ALL) EQ_REFL])
% ================================================================= %

 THEN FIRST_ASSUM				% state_abs is top_of_cycle %
      (\th. (ASSUME_TAC o (porr[state_abs_thm])
			o (AP_TERM "state_abs")) th ? NO_TAC)
 THEN IMP_RES_TAC LD_opcode_lemma 		% opcode_bits assumption %
 THEN port[when]
 THEN BETA_TAC
					% Next assumption %
 THEN IMP_RES_n_THEN 4 ASSUME_TAC LD_Next'
% ================================================================= %
 					% rewrite Timeof ... (SUC t) %
 THEN IMP_RES_n_THEN 2 port1 TimeOf_Next_lemma
 THEN port[o_THM]

					% abbreviate times for readability ... %
 THEN ABBREV_TAC "(TimeOf(is_major_state mpc)t)" "t':num"

					% generate req'd assumptions ... %
 THEN IMP_RES_n_THEN 3 ASSUME_TAC
                       well_formed_free_list_lemma
	    % only 3 of the 6 free cell inequalities are likely needed %
 THEN IMP_RES_n_THEN 2			% mem0 NIL_addr = ... %
      (\th. (free_in "NIL_addr" (concl th)) => ASSUME_TAC th | ALL_TAC)
      reserved_words_constraint
 THEN IMP_RES_n_THEN 2			% nonintersecting mem0 free c %
      (\th. (free_in "c:^w14_mvec" (concl th))
             => ASSUME_TAC th
              | ALL_TAC)
      well_formed_free_list_nonintersection_lemma

 THEN port[LD_trans]                    % unfold spec %
% ================================================================= %
			                % expand the M_* ops %
 THEN port[M_CDR]                       % rewrite M_CDR c  %
 THEN IMP_RES_THEN port1 car_cdr_mem_abs_lemma
 THEN port[M_CAR]                       % rewrite M_CAR (cdr c)  %
 THEN IMP_RES_THEN port1 car_cdr_mem_abs_lemma
 THEN port[M_CAR; M_CDR]                       % rewrite M_CDR c  %
 THEN IMP_RES_THEN port1 car_cdr_mem_abs_lemma
 THEN IMP_RES_THEN port1 number_mem_abs_lemma

 THEN port[LET_THM] THEN BETA_TAC
 THEN port[LET_THM] THEN BETA_TAC
 THEN IMP_RES_THEN port1 car_nth_cdr_lemma
 THEN port [SYM_RULE l2]
 THEN IMP_RES_THEN port1 car_nth_cdr_lemma
				% rewrite the 1st M_Cons %
 THEN port[M_Cons_tr]
 THEN IMP_RES_n_THEN 3 port1 (hd(IMP_CANON M_Cons_unfold_1_thm))
					% unwind the cell_mem_free let binding %
 THEN port[LET_THM]
 THEN BETA_TAC
 THEN prt[cell_of; mem_free_of; free_of; mem_of]

 THEN port[M_CDR]			% unwind M_CDR (c,mem1, ) %
 THEN IMP_RES_n_THEN 3
      ((IMP_RES_THEN (port1 o (MATCH_MP car_cdr_mem_abs_lemma) o SPEC_ALL))
       o snd
       o EQ_IMP_RULE
       o (AP_TERM "is_cons")
       o SPEC_ALL)
      (hd(IMP_CANON Store14_root_1_lemma))
 THEN IMP_RES_n_THEN 4			% unwind M_Cdr (cdr(mem1 c),mem1, ) %
      ((IMP_RES_THEN (port1 o (MATCH_MP car_cdr_mem_abs_lemma) o SPEC_ALL))
       o snd
       o EQ_IMP_RULE
       o (AP_TERM "is_cons")
       o SPEC_ALL)
      (hd(IMP_CANON Store14_car_cdr_1_lemma))
					% simplify _imp view %
 THEN IMP_RES_n_THEN 4 SUBST1_TAC LD_state'
 THEN port[state_abs_thm; l2]
 THEN REFL_TAC
 );;
% ================================================================= %
save_thm(`correctness_LD`,correctness_LD);;

close_theory ();;

print_theory `-`;;
