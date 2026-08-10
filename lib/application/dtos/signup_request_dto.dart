class SignUpRequestDto {
  final String fname;
  final String? mname;
  final String lname;
  final String address;
  final String email;
  final String password;
  final String contactNum;
  final String roleId;

  const SignUpRequestDto({
    required this.fname,
    this.mname,
    required this.lname,
    required this.address,
    required this.email,
    required this.password,
    required this.contactNum,
    required this.roleId,
  });

  Map<String, dynamic> toJson() => {
    'fname': fname,
    'mname': mname,
    'lname': lname,
    'address': address,
    'email': email,
    'password': password,
    'contact_Num': contactNum,
    'role': roleId,
  };
}