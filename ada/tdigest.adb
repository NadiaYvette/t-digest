--  tdigest.adb
--
--  Dunning t-digest -- merging digest variant with K_1 scale function.
--  Uses an array-backed 2-3-4 tree with four-component monoidal measures.

with Ada.Numerics.Long_Elementary_Functions;

package body TDigest is

   use Ada.Numerics.Long_Elementary_Functions;

   Pi : constant Long_Float := 3.14159_26535_89793_23846;

   --  Rename the tree's Key_Array for convenience
   subtype Tree_Key_Array is Centroid_Tree.Key_Array;

   --  ---------------------------------------------------------------
   --  Measure operations (generic formals for Tree234)
   --  ---------------------------------------------------------------

   function Measure_One (C : Centroid) return Td_Measure is
   begin
      return (Weight          => C.Weight,
              Count           => 1,
              Max_Mean        => C.Mean,
              Mean_Weight_Sum => C.Mean * C.Weight);
   end Measure_One;

   function Combine_Measures (A, B : Td_Measure) return Td_Measure is
   begin
      return (Weight          => A.Weight + B.Weight,
              Count           => A.Count + B.Count,
              Max_Mean        => Long_Float'Max (A.Max_Mean, B.Max_Mean),
              Mean_Weight_Sum => A.Mean_Weight_Sum + B.Mean_Weight_Sum);
   end Combine_Measures;

   function Identity_Measure return Td_Measure is
   begin
      return (Weight          => 0.0,
              Count           => 0,
              Max_Mean        => Long_Float'First,
              Mean_Weight_Sum => 0.0);
   end Identity_Measure;

   function Compare_Centroids (A, B : Centroid) return Integer is
   begin
      if A.Mean < B.Mean then
         return -1;
      elsif A.Mean > B.Mean then
         return 1;
      else
         return 0;
      end if;
   end Compare_Centroids;

   function Measure_Weight (M : Td_Measure) return Long_Float is
   begin
      return M.Weight;
   end Measure_Weight;

   --  ---------------------------------------------------------------
   --  Internal helpers
   --  ---------------------------------------------------------------

   --  K_1 scale function: k(q) = (compression / (2*pi)) * arcsin(2*q - 1)
   function K (Q : Long_Float; D : Long_Float) return Long_Float is
      Arg : Long_Float := 2.0 * Q - 1.0;
   begin
      if Arg < -1.0 then
         Arg := -1.0;
      elsif Arg > 1.0 then
         Arg := 1.0;
      end if;
      return (D / (2.0 * Pi)) * Arcsin (Arg);
   end K;

   --  In-place insertion sort of Arr(First .. Last) by Mean.
   procedure Sort_By_Mean (Arr   : in out Tree_Key_Array;
                           First : Positive;
                           Last  : Natural) is
      Tmp : Centroid;
      J   : Integer;
   begin
      if Last <= First then
         return;
      end if;
      for I in First + 1 .. Last loop
         Tmp := Arr (I);
         J := I - 1;
         while J >= First and then Arr (J).Mean > Tmp.Mean loop
            Arr (J + 1) := Arr (J);
            J := J - 1;
         end loop;
         Arr (J + 1) := Tmp;
      end loop;
   end Sort_By_Mean;

   --  Merge centroid Src into Dst using weighted mean.
   procedure Merge_Centroid (Dst : in out Centroid;
                             Src : Centroid) is
      New_Weight : constant Long_Float := Dst.Weight + Src.Weight;
   begin
      Dst.Mean   := (Dst.Mean * Dst.Weight + Src.Mean * Src.Weight)
                     / New_Weight;
      Dst.Weight := New_Weight;
   end Merge_Centroid;

   --  ---------------------------------------------------------------
   --  Public operations
   --  ---------------------------------------------------------------

   function Create (Compression : Long_Float := 100.0) return T_Digest is
      TD : T_Digest;
   begin
      TD.Compression := Compression;
      TD.Buf_Cap     := Natural'Min
        (Max_Buffer,
         Natural (Long_Float'Ceiling (Compression * 5.0)));
      return TD;
   end Create;

   procedure Add (TD     : in out T_Digest;
                  Value  : Long_Float;
                  Weight : Long_Float := 1.0) is
   begin
      TD.Buf_Count := TD.Buf_Count + 1;
      TD.Buf (TD.Buf_Count) := (Mean => Value, Weight => Weight);
      TD.Total_Weight := TD.Total_Weight + Weight;

      if Value < TD.Min_Val then
         TD.Min_Val := Value;
      end if;
      if Value > TD.Max_Val then
         TD.Max_Val := Value;
      end if;

      if TD.Buf_Count >= TD.Buf_Cap then
         Compress (TD);
      end if;
   end Add;

   procedure Compress (TD : in out T_Digest) is
      Tree_Size : constant Natural := Centroid_Tree.Size (TD.Tree_Data);
      Total     : constant Natural := Tree_Size + TD.Buf_Count;

      Max_Work : constant Natural := Natural'Max (Total, 1);
      All_Items : Tree_Key_Array (1 .. Max_Work);
      All_Count : Natural := 0;
      New_Items : Tree_Key_Array (1 .. Max_Work);
      New_Count : Natural := 0;

      Weight_So_Far : Long_Float := 0.0;
      N             : Long_Float;
      Proposed      : Long_Float;
      Q0, Q1        : Long_Float;
   begin
      if Total = 0 then
         return;
      end if;
      if Total <= 1 and then TD.Buf_Count = 0 then
         return;
      end if;

      --  Collect existing centroids from tree
      Centroid_Tree.Collect (TD.Tree_Data, All_Items, All_Count);

      --  Append buffer entries
      for I in 1 .. TD.Buf_Count loop
         All_Items (All_Count + I) := TD.Buf (I);
      end loop;
      All_Count := All_Count + TD.Buf_Count;
      TD.Buf_Count := 0;

      --  Sort by mean
      Sort_By_Mean (All_Items, 1, All_Count);

      N := TD.Total_Weight;

      --  Start the first new centroid
      New_Count := 1;
      New_Items (1) := All_Items (1);

      for I in 2 .. All_Count loop
         Proposed := New_Items (New_Count).Weight + All_Items (I).Weight;
         Q0 := Weight_So_Far / N;
         Q1 := (Weight_So_Far + Proposed) / N;

         if (Proposed <= 1.0 and then All_Count > 1)
           or else (K (Q1, TD.Compression) - K (Q0, TD.Compression) <= 1.0)
         then
            Merge_Centroid (New_Items (New_Count), All_Items (I));
         else
            Weight_So_Far := Weight_So_Far + New_Items (New_Count).Weight;
            New_Count := New_Count + 1;
            New_Items (New_Count) := All_Items (I);
         end if;
      end loop;

      --  Rebuild tree from sorted merged centroids
      Centroid_Tree.Build_From_Sorted
        (TD.Tree_Data, New_Items (1 .. New_Count));
   end Compress;

   function Quantile (TD : in out T_Digest;
                      Q  : Long_Float) return Long_Float is
      QQ        : Long_Float := Q;
      N         : Long_Float;
      Target    : Long_Float;
      Cumul     : Long_Float := 0.0;
      Mid       : Long_Float;
      Next_Mid  : Long_Float;
      Frac      : Long_Float;
      Sz        : Natural;
   begin
      if TD.Buf_Count > 0 then
         Compress (TD);
      end if;

      Sz := Centroid_Tree.Size (TD.Tree_Data);

      if Sz = 0 then
         return 0.0;
      end if;

      --  Collect centroids from tree
      declare
         Arr   : Tree_Key_Array (1 .. Sz);
         Count : Natural;
      begin
         Centroid_Tree.Collect (TD.Tree_Data, Arr, Count);

         if Count = 1 then
            return Arr (1).Mean;
         end if;

         if QQ < 0.0 then
            QQ := 0.0;
         elsif QQ > 1.0 then
            QQ := 1.0;
         end if;

         N := TD.Total_Weight;
         Target := QQ * N;

         Cumul := 0.0;
         for I in 1 .. Count loop
            Mid := Cumul + Arr (I).Weight / 2.0;

            --  Left boundary
            if I = 1 then
               if Target < Arr (I).Weight / 2.0 then
                  if Arr (I).Weight = 1.0 then
                     return TD.Min_Val;
                  end if;
                  return TD.Min_Val
                    + (Arr (I).Mean - TD.Min_Val)
                      * (Target / (Arr (I).Weight / 2.0));
               end if;
            end if;

            --  Right boundary
            if I = Count then
               declare
                  Remaining : constant Long_Float :=
                    N - Arr (I).Weight / 2.0;
               begin
                  if Target > Remaining then
                     if Arr (I).Weight = 1.0 then
                        return TD.Max_Val;
                     end if;
                     return Arr (I).Mean
                       + (TD.Max_Val - Arr (I).Mean)
                         * ((Target - Remaining)
                            / (Arr (I).Weight / 2.0));
                  end if;
               end;
               return Arr (I).Mean;
            end if;

            --  Middle: linear interpolation
            Next_Mid := Cumul + Arr (I).Weight
                        + Arr (I + 1).Weight / 2.0;

            if Target <= Next_Mid then
               if Next_Mid = Mid then
                  Frac := 0.5;
               else
                  Frac := (Target - Mid) / (Next_Mid - Mid);
               end if;
               return Arr (I).Mean
                 + Frac * (Arr (I + 1).Mean - Arr (I).Mean);
            end if;

            Cumul := Cumul + Arr (I).Weight;
         end loop;

         return TD.Max_Val;
      end;
   end Quantile;

   function CDF (TD : in out T_Digest;
                 X  : Long_Float) return Long_Float is
      N        : Long_Float;
      Cumul    : Long_Float := 0.0;
      Mid      : Long_Float;
      Next_Cum : Long_Float;
      Next_Mid : Long_Float;
      Frac     : Long_Float;
      Inner_W  : Long_Float;
      Right_W  : Long_Float;
      Sz       : Natural;
   begin
      if TD.Buf_Count > 0 then
         Compress (TD);
      end if;

      Sz := Centroid_Tree.Size (TD.Tree_Data);

      if Sz = 0 then
         return 0.0;
      end if;
      if X <= TD.Min_Val then
         return 0.0;
      end if;
      if X >= TD.Max_Val then
         return 1.0;
      end if;

      declare
         Arr   : Tree_Key_Array (1 .. Sz);
         Count : Natural;
      begin
         Centroid_Tree.Collect (TD.Tree_Data, Arr, Count);

         N := TD.Total_Weight;
         Cumul := 0.0;

         for I in 1 .. Count loop
            --  Left boundary
            if I = 1 then
               if X < Arr (I).Mean then
                  Inner_W := Arr (I).Weight / 2.0;
                  if Arr (I).Mean = TD.Min_Val then
                     Frac := 1.0;
                  else
                     Frac := (X - TD.Min_Val)
                             / (Arr (I).Mean - TD.Min_Val);
                  end if;
                  return (Inner_W * Frac) / N;
               elsif X = Arr (I).Mean then
                  return (Arr (I).Weight / 2.0) / N;
               end if;
            end if;

            --  Right boundary
            if I = Count then
               if X > Arr (I).Mean then
                  Inner_W := Arr (I).Weight / 2.0;
                  Right_W := N - Cumul - Arr (I).Weight / 2.0;
                  if TD.Max_Val = Arr (I).Mean then
                     Frac := 0.0;
                  else
                     Frac := (X - Arr (I).Mean)
                             / (TD.Max_Val - Arr (I).Mean);
                  end if;
                  return (Cumul + Arr (I).Weight / 2.0
                          + Right_W * Frac) / N;
               else
                  return (Cumul + Arr (I).Weight / 2.0) / N;
               end if;
            end if;

            --  Middle
            Mid := Cumul + Arr (I).Weight / 2.0;
            Next_Cum := Cumul + Arr (I).Weight;
            Next_Mid := Next_Cum + Arr (I + 1).Weight / 2.0;

            if X < Arr (I + 1).Mean then
               if Arr (I).Mean = Arr (I + 1).Mean then
                  return (Mid + (Next_Mid - Mid) / 2.0) / N;
               end if;
               Frac := (X - Arr (I).Mean)
                       / (Arr (I + 1).Mean - Arr (I).Mean);
               return (Mid + Frac * (Next_Mid - Mid)) / N;
            end if;

            Cumul := Cumul + Arr (I).Weight;
         end loop;

         return 1.0;
      end;
   end CDF;

   procedure Merge (TD    : in out T_Digest;
                    Other : in out T_Digest) is
      Other_Sz : Natural;
   begin
      --  Flush Other's buffer
      if Other.Buf_Count > 0 then
         Compress (Other);
      end if;

      Other_Sz := Centroid_Tree.Size (Other.Tree_Data);

      --  Collect Other's centroids and add them to TD
      if Other_Sz > 0 then
         declare
            Arr   : Tree_Key_Array (1 .. Other_Sz);
            Count : Natural;
         begin
            Centroid_Tree.Collect (Other.Tree_Data, Arr, Count);
            for I in 1 .. Count loop
               Add (TD, Arr (I).Mean, Arr (I).Weight);
            end loop;
         end;
      end if;
   end Merge;

   function Centroid_Count (TD : in out T_Digest) return Natural is
   begin
      if TD.Buf_Count > 0 then
         Compress (TD);
      end if;
      return Centroid_Tree.Size (TD.Tree_Data);
   end Centroid_Count;

end TDigest;
