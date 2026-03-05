--  tdigest_oop.adb
--
--  Object-oriented (tagged-type) interface -- implementation.

package body TDigest_OOP is

   procedure Initialize (Self        : out Digest_Type;
                         Compression : Long_Float := 100.0) is
   begin
      Self.Impl := TDigest.Create (Compression);
   end Initialize;

   procedure Add (Self   : in out Digest_Type;
                  Value  : Long_Float;
                  Weight : Long_Float := 1.0) is
   begin
      TDigest.Add (Self.Impl, Value, Weight);
   end Add;

   procedure Compress (Self : in out Digest_Type) is
   begin
      TDigest.Compress (Self.Impl);
   end Compress;

   function Query_Quantile (Self : in out Digest_Type;
                            Q    : Long_Float) return Long_Float is
   begin
      return TDigest.Quantile (Self.Impl, Q);
   end Query_Quantile;

   function Query_CDF (Self : in out Digest_Type;
                       X    : Long_Float) return Long_Float is
   begin
      return TDigest.CDF (Self.Impl, X);
   end Query_CDF;

   procedure Merge (Self  : in out Digest_Type;
                    Other : in out Digest_Type) is
   begin
      TDigest.Merge (Self.Impl, Other.Impl);
   end Merge;

   function Centroid_Count (Self : in out Digest_Type) return Natural is
   begin
      return TDigest.Centroid_Count (Self.Impl);
   end Centroid_Count;

   function Total_Weight (Self : Digest_Type) return Long_Float is
   begin
      return Self.Impl.Total_Weight;
   end Total_Weight;

   function Min_Value (Self : Digest_Type) return Long_Float is
   begin
      return Self.Impl.Min_Val;
   end Min_Value;

   function Max_Value (Self : Digest_Type) return Long_Float is
   begin
      return Self.Impl.Max_Val;
   end Max_Value;

end TDigest_OOP;
