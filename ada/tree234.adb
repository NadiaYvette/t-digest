--  tree234.adb
--
--  Generic array-backed 2-3-4 tree with monoidal measures.

with Ada.Unchecked_Deallocation;

package body Tree234 is

   --  ---------------------------------------------------------------
   --  Pool management
   --  ---------------------------------------------------------------

   procedure Free_Node_Array is new Ada.Unchecked_Deallocation
     (Node_Array, Node_Array_Access);

   procedure Free_Int_Array is new Ada.Unchecked_Deallocation
     (Int_Array, Int_Array_Access);

   procedure Ensure_Pool (T : in out Tree) is
   begin
      if T.Pool = null then
         T.Pool := new Node_Array (0 .. Initial_Pool_Size - 1);
         T.Pool_Count := 0;
         T.Free_List := new Int_Array (0 .. Initial_Pool_Size - 1);
         T.Free_Count := 0;
      end if;
   end Ensure_Pool;

   procedure Grow_Pool (T : in out Tree) is
      Old_Size : constant Natural := T.Pool'Length;
      New_Size : constant Natural := Old_Size * 2;
      New_Pool : Node_Array_Access := new Node_Array (0 .. New_Size - 1);
      New_Free : Int_Array_Access := new Int_Array (0 .. New_Size - 1);
   begin
      New_Pool (0 .. Old_Size - 1) := T.Pool.all;
      New_Free (0 .. Old_Size - 1) := T.Free_List.all;
      Free_Node_Array (T.Pool);
      Free_Int_Array (T.Free_List);
      T.Pool := New_Pool;
      T.Free_List := New_Free;
   end Grow_Pool;

   function Alloc_Node (T : in out Tree) return Integer is
      Idx : Integer;
      Nd  : Node;
   begin
      Ensure_Pool (T);

      if T.Free_Count > 0 then
         T.Free_Count := T.Free_Count - 1;
         Idx := T.Free_List (T.Free_Count);
         Nd.Measure := Identity;
         T.Pool (Idx) := Nd;
         return Idx;
      end if;

      if T.Pool_Count >= T.Pool'Length then
         Grow_Pool (T);
      end if;

      Idx := T.Pool_Count;
      T.Pool_Count := T.Pool_Count + 1;
      Nd.Measure := Identity;
      T.Pool (Idx) := Nd;
      return Idx;
   end Alloc_Node;

   --  ---------------------------------------------------------------
   --  Internal helpers
   --  ---------------------------------------------------------------

   function Is_Leaf (T : Tree; Idx : Integer) return Boolean is
   begin
      return T.Pool (Idx).Children (0) = No_Child;
   end Is_Leaf;

   function Is_4Node (T : Tree; Idx : Integer) return Boolean is
   begin
      return T.Pool (Idx).N = 3;
   end Is_4Node;

   procedure Recompute_Measure (T : in out Tree; Idx : Integer) is
      Nd : Node renames T.Pool (Idx);
      M  : Measure_Type := Identity;
   begin
      for I in 0 .. Nd.N loop
         if Nd.Children (I) /= No_Child then
            M := Combine (M, T.Pool (Nd.Children (I)).Measure);
         end if;
         if I < Nd.N then
            M := Combine (M, Measure_One (Nd.Keys (I + 1)));
         end if;
      end loop;
      Nd.Measure := M;
   end Recompute_Measure;

   --  Split a 4-node child at position Child_Pos of parent.
   procedure Split_Child (T          : in out Tree;
                          Parent_Idx : Integer;
                          Child_Pos  : Natural) is
      Child_Idx : constant Integer :=
        T.Pool (Parent_Idx).Children (Child_Pos);

      --  Save child data before potential reallocation
      K1 : constant Key_Type := T.Pool (Child_Idx).Keys (1);
      K2 : constant Key_Type := T.Pool (Child_Idx).Keys (2);
      K3 : constant Key_Type := T.Pool (Child_Idx).Keys (3);
      C0 : constant Integer  := T.Pool (Child_Idx).Children (0);
      C1 : constant Integer  := T.Pool (Child_Idx).Children (1);
      C2 : constant Integer  := T.Pool (Child_Idx).Children (2);
      C3 : constant Integer  := T.Pool (Child_Idx).Children (3);

      Right_Idx : Integer;
      PN        : Natural;
   begin
      --  Create right node with K3, C2, C3
      Right_Idx := Alloc_Node (T);
      T.Pool (Right_Idx).N := 1;
      T.Pool (Right_Idx).Keys (1) := K3;
      T.Pool (Right_Idx).Children (0) := C2;
      T.Pool (Right_Idx).Children (1) := C3;

      --  Shrink child (left) to K1, C0, C1
      T.Pool (Child_Idx).N := 1;
      T.Pool (Child_Idx).Keys (1) := K1;
      T.Pool (Child_Idx).Children (0) := C0;
      T.Pool (Child_Idx).Children (1) := C1;
      T.Pool (Child_Idx).Children (2) := No_Child;
      T.Pool (Child_Idx).Children (3) := No_Child;

      Recompute_Measure (T, Child_Idx);
      Recompute_Measure (T, Right_Idx);

      --  Insert mid key (K2) into parent at Child_Pos
      PN := T.Pool (Parent_Idx).N;
      --  Shift keys and children right
      for I in reverse Child_Pos .. PN - 1 loop
         T.Pool (Parent_Idx).Keys (I + 2) := T.Pool (Parent_Idx).Keys (I + 1);
         T.Pool (Parent_Idx).Children (I + 2) :=
           T.Pool (Parent_Idx).Children (I + 1);
      end loop;
      T.Pool (Parent_Idx).Keys (Child_Pos + 1) := K2;
      T.Pool (Parent_Idx).Children (Child_Pos + 1) := Right_Idx;
      T.Pool (Parent_Idx).N := PN + 1;

      Recompute_Measure (T, Parent_Idx);
   end Split_Child;

   --  Insert key into a non-full node's subtree.
   procedure Insert_Non_Full (T   : in out Tree;
                              Idx : Integer;
                              K   : Key_Type) is
      Pos : Natural;
      N   : Natural;
   begin
      if Is_Leaf (T, Idx) then
         --  Insert key in sorted position
         N := T.Pool (Idx).N;
         Pos := N;
         while Pos > 0
           and then Compare (K, T.Pool (Idx).Keys (Pos)) < 0
         loop
            if Pos < 3 then
               T.Pool (Idx).Keys (Pos + 1) := T.Pool (Idx).Keys (Pos);
            end if;
            Pos := Pos - 1;
         end loop;
         T.Pool (Idx).Keys (Pos + 1) := K;
         T.Pool (Idx).N := N + 1;
         Recompute_Measure (T, Idx);
         return;
      end if;

      --  Find child to descend into (0-based child index)
      Pos := 0;
      while Pos < T.Pool (Idx).N
        and then Compare (K, T.Pool (Idx).Keys (Pos + 1)) >= 0
      loop
         Pos := Pos + 1;
      end loop;

      --  If that child is a 4-node, split it first
      if Is_4Node (T, T.Pool (Idx).Children (Pos)) then
         Split_Child (T, Idx, Pos);
         --  After split, mid key is at Keys(Pos+1). Decide which side.
         if Compare (K, T.Pool (Idx).Keys (Pos + 1)) >= 0 then
            Pos := Pos + 1;
         end if;
      end if;

      Insert_Non_Full (T, T.Pool (Idx).Children (Pos), K);
      Recompute_Measure (T, Idx);
   end Insert_Non_Full;

   --  In-order traversal helper
   procedure For_Each_Impl (T     : Tree;
                            Idx   : Integer;
                            Arr   : in out Key_Array;
                            Pos   : in out Natural) is
      Nd : Node renames T.Pool (Idx);
   begin
      if Idx = No_Child then
         return;
      end if;
      for I in 0 .. Nd.N loop
         if Nd.Children (I) /= No_Child then
            For_Each_Impl (T, Nd.Children (I), Arr, Pos);
         end if;
         if I < Nd.N then
            Pos := Pos + 1;
            Arr (Pos) := Nd.Keys (I + 1);
         end if;
      end loop;
   end For_Each_Impl;

   --  Count elements in subtree
   function Subtree_Count (T : Tree; Idx : Integer) return Natural is
      Nd : Node renames T.Pool (Idx);
      C  : Natural;
   begin
      if Idx = No_Child then
         return 0;
      end if;
      C := Nd.N;
      for I in 0 .. Nd.N loop
         if Nd.Children (I) /= No_Child then
            C := C + Subtree_Count (T, Nd.Children (I));
         end if;
      end loop;
      return C;
   end Subtree_Count;

   --  Find_By_Weight recursive helper
   function Find_By_Weight_Impl
     (T          : Tree;
      Idx        : Integer;
      Target     : Long_Float;
      Cum        : Long_Float;
      Global_Idx : Natural) return Weight_Result
   is
      Nd          : Node renames T.Pool (Idx);
      Running_Cum : Long_Float := Cum;
      Running_Idx : Natural := Global_Idx;
      Child_Wt    : Long_Float;
      Key_Wt      : Long_Float;
      Result      : Weight_Result;
   begin
      if Idx = No_Child then
         Result.Found := False;
         return Result;
      end if;

      for I in 0 .. Nd.N loop
         --  Process child
         if Nd.Children (I) /= No_Child then
            Child_Wt := Weight_Of (T.Pool (Nd.Children (I)).Measure);
            if Running_Cum + Child_Wt >= Target then
               return Find_By_Weight_Impl
                 (T, Nd.Children (I), Target, Running_Cum, Running_Idx);
            end if;
            Running_Cum := Running_Cum + Child_Wt;
            Running_Idx := Running_Idx + Subtree_Count (T, Nd.Children (I));
         end if;

         if I < Nd.N then
            Key_Wt := Weight_Of (Measure_One (Nd.Keys (I + 1)));
            if Running_Cum + Key_Wt >= Target then
               Result.Key := Nd.Keys (I + 1);
               Result.Cum_Before := Running_Cum;
               Result.Index := Running_Idx;
               Result.Found := True;
               return Result;
            end if;
            Running_Cum := Running_Cum + Key_Wt;
            Running_Idx := Running_Idx + 1;
         end if;
      end loop;

      Result.Found := False;
      return Result;
   end Find_By_Weight_Impl;

   --  Build balanced tree recursively from sorted array
   function Build_Recursive
     (T   : in out Tree;
      Arr : Key_Array;
      Lo  : Integer;
      Hi  : Integer) return Integer
   is
      N_Elems : constant Integer := Hi - Lo;
      Idx     : Integer;
      Mid_Pos : Integer;
      Left, Right, Center : Integer;
      Third, M1, M2 : Integer;
      C0, C1, C2 : Integer;
   begin
      if N_Elems <= 0 then
         return No_Child;
      end if;

      if N_Elems <= 3 then
         Idx := Alloc_Node (T);
         T.Pool (Idx).N := N_Elems;
         for I in 0 .. N_Elems - 1 loop
            T.Pool (Idx).Keys (I + 1) := Arr (Lo + I);
         end loop;
         Recompute_Measure (T, Idx);
         return Idx;
      end if;

      if N_Elems <= 7 then
         Mid_Pos := Lo + N_Elems / 2;
         Left := Build_Recursive (T, Arr, Lo, Mid_Pos);
         Right := Build_Recursive (T, Arr, Mid_Pos + 1, Hi);
         Idx := Alloc_Node (T);
         T.Pool (Idx).N := 1;
         T.Pool (Idx).Keys (1) := Arr (Mid_Pos);
         T.Pool (Idx).Children (0) := Left;
         T.Pool (Idx).Children (1) := Right;
         Recompute_Measure (T, Idx);
         return Idx;
      end if;

      --  For larger, use 3-node
      Third := N_Elems / 3;
      M1 := Lo + Third;
      M2 := Lo + 2 * Third + 1;
      C0 := Build_Recursive (T, Arr, Lo, M1);
      C1 := Build_Recursive (T, Arr, M1 + 1, M2);
      C2 := Build_Recursive (T, Arr, M2 + 1, Hi);
      Idx := Alloc_Node (T);
      T.Pool (Idx).N := 2;
      T.Pool (Idx).Keys (1) := Arr (M1);
      T.Pool (Idx).Keys (2) := Arr (M2);
      T.Pool (Idx).Children (0) := C0;
      T.Pool (Idx).Children (1) := C1;
      T.Pool (Idx).Children (2) := C2;
      Recompute_Measure (T, Idx);
      return Idx;
   end Build_Recursive;

   --  ---------------------------------------------------------------
   --  Public operations
   --  ---------------------------------------------------------------

   procedure Insert (T : in out Tree; K : Key_Type) is
      Old_Root : Integer;
   begin
      if T.Root = No_Child then
         T.Root := Alloc_Node (T);
         T.Pool (T.Root).N := 1;
         T.Pool (T.Root).Keys (1) := K;
         Recompute_Measure (T, T.Root);
         T.Count := T.Count + 1;
         return;
      end if;

      --  If root is a 4-node, split it
      if Is_4Node (T, T.Root) then
         Old_Root := T.Root;
         T.Root := Alloc_Node (T);
         T.Pool (T.Root).N := 0;
         T.Pool (T.Root).Children (0) := Old_Root;
         Split_Child (T, T.Root, 0);
      end if;

      Insert_Non_Full (T, T.Root, K);
      T.Count := T.Count + 1;
   end Insert;

   procedure Clear (T : in out Tree) is
   begin
      T.Pool_Count := 0;
      T.Free_Count := 0;
      T.Root := No_Child;
      T.Count := 0;
   end Clear;

   function Size (T : Tree) return Natural is
   begin
      return T.Count;
   end Size;

   function Root_Measure (T : Tree) return Measure_Type is
   begin
      if T.Root = No_Child then
         return Identity;
      end if;
      return T.Pool (T.Root).Measure;
   end Root_Measure;

   procedure Collect (T     : Tree;
                      Arr   : out Key_Array;
                      Count : out Natural) is
      Pos : Natural := 0;
   begin
      Count := 0;
      if T.Root = No_Child then
         return;
      end if;
      For_Each_Impl (T, T.Root, Arr, Pos);
      Count := Pos;
   end Collect;

   function Find_By_Weight (T      : Tree;
                            Target : Long_Float) return Weight_Result is
      Result : Weight_Result;
   begin
      if T.Root = No_Child then
         Result.Found := False;
         return Result;
      end if;
      return Find_By_Weight_Impl (T, T.Root, Target, 0.0, 0);
   end Find_By_Weight;

   procedure Build_From_Sorted (T   : in out Tree;
                                Arr : Key_Array) is
   begin
      Clear (T);
      if Arr'Length = 0 then
         return;
      end if;
      T.Count := Arr'Length;
      T.Root := Build_Recursive
        (T, Arr, Arr'First, Arr'First + Arr'Length);
   end Build_From_Sorted;

end Tree234;
