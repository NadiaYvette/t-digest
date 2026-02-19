--  tdigest.adb
--
--  Dunning t-digest -- merging digest variant with K_1 scale function.

with Ada.Numerics.Long_Elementary_Functions;

package body TDigest is

   use Ada.Numerics.Long_Elementary_Functions;

   Pi : constant Long_Float := 3.14159_26535_89793_23846;

   --  ---------------------------------------------------------------
   --  Internal helpers
   --  ---------------------------------------------------------------

   --  K_1 scale function: k(q) = (compression / (2*pi)) * arcsin(2*q - 1)
   function K (Q : Long_Float; D : Long_Float) return Long_Float is
      Arg : Long_Float := 2.0 * Q - 1.0;
   begin
      --  Clamp argument to [-1, 1] for numerical safety.
      if Arg < -1.0 then
         Arg := -1.0;
      elsif Arg > 1.0 then
         Arg := 1.0;
      end if;
      return (D / (2.0 * Pi)) * Arcsin (Arg);
   end K;

   --  In-place insertion sort of Arr(First .. Last) by Mean.
   procedure Sort_By_Mean (Arr   : in out Centroid_Array;
                           First : Positive;
                           Last  : Natural) is
      Key : Centroid;
      J   : Integer;  --  Integer so it can go below First (= 0).
   begin
      if Last <= First then
         return;
      end if;
      for I in First + 1 .. Last loop
         Key := Arr (I);
         J := I - 1;
         while J >= First and then Arr (J).Mean > Key.Mean loop
            Arr (J + 1) := Arr (J);
            J := J - 1;
         end loop;
         Arr (J + 1) := Key;
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
      --  Temporary workspace: centroids + buffer combined.
      Total : constant Natural := TD.Num_Centroids + TD.Buf_Count;

      subtype Work_Range is Positive range 1 .. Max_Centroids + Max_Buffer;
      All_Items : Centroid_Array (Work_Range);
      New_Items : Centroid_Array (Work_Range);
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

      --  Combine existing centroids and buffer.
      for I in 1 .. TD.Num_Centroids loop
         All_Items (I) := TD.Centroids (I);
      end loop;
      for I in 1 .. TD.Buf_Count loop
         All_Items (TD.Num_Centroids + I) := TD.Buf (I);
      end loop;
      TD.Buf_Count := 0;

      --  Sort by mean.
      Sort_By_Mean (All_Items, 1, Total);

      N := TD.Total_Weight;

      --  Start the first new centroid.
      New_Count := 1;
      New_Items (1) := All_Items (1);

      for I in 2 .. Total loop
         Proposed := New_Items (New_Count).Weight + All_Items (I).Weight;
         Q0 := Weight_So_Far / N;
         Q1 := (Weight_So_Far + Proposed) / N;

         if (Proposed <= 1.0 and then Total > 1)
           or else (K (Q1, TD.Compression) - K (Q0, TD.Compression) <= 1.0)
         then
            --  Merge into current centroid.
            Merge_Centroid (New_Items (New_Count), All_Items (I));
         else
            --  Start a new centroid.
            Weight_So_Far := Weight_So_Far + New_Items (New_Count).Weight;
            New_Count := New_Count + 1;
            New_Items (New_Count) := All_Items (I);
         end if;
      end loop;

      --  Copy result back.
      TD.Num_Centroids := New_Count;
      for I in 1 .. New_Count loop
         TD.Centroids (I) := New_Items (I);
      end loop;
   end Compress;

   function Quantile (TD : in out T_Digest;
                      Q  : Long_Float) return Long_Float is
      QQ       : Long_Float := Q;
      N        : Long_Float;
      Target   : Long_Float;
      Cumul    : Long_Float := 0.0;
      Mid      : Long_Float;
      Next_Mid : Long_Float;
      Frac     : Long_Float;
   begin
      --  Flush buffer.
      if TD.Buf_Count > 0 then
         Compress (TD);
      end if;

      if TD.Num_Centroids = 0 then
         return 0.0;
      end if;
      if TD.Num_Centroids = 1 then
         return TD.Centroids (1).Mean;
      end if;

      --  Clamp Q.
      if QQ < 0.0 then
         QQ := 0.0;
      elsif QQ > 1.0 then
         QQ := 1.0;
      end if;

      N := TD.Total_Weight;
      Target := QQ * N;

      for I in 1 .. TD.Num_Centroids loop
         Mid := Cumul + TD.Centroids (I).Weight / 2.0;

         --  Left boundary: interpolate between Min_Val and first centroid.
         if I = 1 then
            if Target < TD.Centroids (I).Weight / 2.0 then
               if TD.Centroids (I).Weight = 1.0 then
                  return TD.Min_Val;
               end if;
               return TD.Min_Val
                 + (TD.Centroids (I).Mean - TD.Min_Val)
                   * (Target / (TD.Centroids (I).Weight / 2.0));
            end if;
         end if;

         --  Right boundary: interpolate between last centroid and Max_Val.
         if I = TD.Num_Centroids then
            declare
               Remaining : constant Long_Float :=
                 N - TD.Centroids (I).Weight / 2.0;
            begin
               if Target > Remaining then
                  if TD.Centroids (I).Weight = 1.0 then
                     return TD.Max_Val;
                  end if;
                  return TD.Centroids (I).Mean
                    + (TD.Max_Val - TD.Centroids (I).Mean)
                      * ((Target - Remaining)
                         / (TD.Centroids (I).Weight / 2.0));
               end if;
            end;
            return TD.Centroids (I).Mean;
         end if;

         --  Middle: linear interpolation between adjacent centroid midpoints.
         Next_Mid := Cumul + TD.Centroids (I).Weight
                     + TD.Centroids (I + 1).Weight / 2.0;

         if Target <= Next_Mid then
            if Next_Mid = Mid then
               Frac := 0.5;
            else
               Frac := (Target - Mid) / (Next_Mid - Mid);
            end if;
            return TD.Centroids (I).Mean
              + Frac * (TD.Centroids (I + 1).Mean - TD.Centroids (I).Mean);
         end if;

         Cumul := Cumul + TD.Centroids (I).Weight;
      end loop;

      return TD.Max_Val;
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
   begin
      --  Flush buffer.
      if TD.Buf_Count > 0 then
         Compress (TD);
      end if;

      if TD.Num_Centroids = 0 then
         return 0.0;
      end if;
      if X <= TD.Min_Val then
         return 0.0;
      end if;
      if X >= TD.Max_Val then
         return 1.0;
      end if;

      N := TD.Total_Weight;

      for I in 1 .. TD.Num_Centroids loop
         --  Left boundary.
         if I = 1 then
            if X < TD.Centroids (I).Mean then
               Inner_W := TD.Centroids (I).Weight / 2.0;
               if TD.Centroids (I).Mean = TD.Min_Val then
                  Frac := 1.0;
               else
                  Frac := (X - TD.Min_Val)
                          / (TD.Centroids (I).Mean - TD.Min_Val);
               end if;
               return (Inner_W * Frac) / N;
            elsif X = TD.Centroids (I).Mean then
               return (TD.Centroids (I).Weight / 2.0) / N;
            end if;
         end if;

         --  Right boundary.
         if I = TD.Num_Centroids then
            if X > TD.Centroids (I).Mean then
               Inner_W := TD.Centroids (I).Weight / 2.0;
               Right_W := N - Cumul - TD.Centroids (I).Weight / 2.0;
               if TD.Max_Val = TD.Centroids (I).Mean then
                  Frac := 0.0;
               else
                  Frac := (X - TD.Centroids (I).Mean)
                          / (TD.Max_Val - TD.Centroids (I).Mean);
               end if;
               return (Cumul + TD.Centroids (I).Weight / 2.0
                       + Right_W * Frac) / N;
            else
               return (Cumul + TD.Centroids (I).Weight / 2.0) / N;
            end if;
         end if;

         --  Middle: interpolate between adjacent centroid midpoints.
         Mid := Cumul + TD.Centroids (I).Weight / 2.0;
         Next_Cum := Cumul + TD.Centroids (I).Weight;
         Next_Mid := Next_Cum + TD.Centroids (I + 1).Weight / 2.0;

         if X < TD.Centroids (I + 1).Mean then
            if TD.Centroids (I).Mean = TD.Centroids (I + 1).Mean then
               return (Mid + (Next_Mid - Mid) / 2.0) / N;
            end if;
            Frac := (X - TD.Centroids (I).Mean)
                    / (TD.Centroids (I + 1).Mean - TD.Centroids (I).Mean);
            return (Mid + Frac * (Next_Mid - Mid)) / N;
         end if;

         Cumul := Cumul + TD.Centroids (I).Weight;
      end loop;

      return 1.0;
   end CDF;

   procedure Merge (TD    : in out T_Digest;
                    Other : in out T_Digest) is
   begin
      --  Flush Other's buffer.
      if Other.Buf_Count > 0 then
         Compress (Other);
      end if;

      --  Add each of Other's centroids as buffered values in TD.
      for I in 1 .. Other.Num_Centroids loop
         Add (TD, Other.Centroids (I).Mean, Other.Centroids (I).Weight);
      end loop;
   end Merge;

   function Centroid_Count (TD : in out T_Digest) return Natural is
   begin
      if TD.Buf_Count > 0 then
         Compress (TD);
      end if;
      return TD.Num_Centroids;
   end Centroid_Count;

end TDigest;
