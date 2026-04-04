class ResponseData {
  final success;
  final status;
  final data;
  final message;
  final emailNotVerified;
  final errors;

  // ignore: non_constant_typeentifier_names
  ResponseData({
    required this.success,
    required this.data,
    required this.message,
    required this.status,
    required this.emailNotVerified,
    this.errors,
  });
  @override
  String toString() {
    return '{ $success, $data, $message, $status, $emailNotVerified, $errors}';
  }

  // ignore: missing_return

  factory ResponseData.fromJson(dynamic json) {
    return ResponseData(
      success: json['success'] ?? false,
      data: json['data'],
      message: json['message'] ?? '',
      status: json["status"],
      emailNotVerified: json["emailNotVerified"],
      errors: json["errors"],
    );
  }

  static Map<String, dynamic> toMap(ResponseData data) => {
    'success': data.success,
    'data': data.data,
    'message': data.message,
    'status': data.status,
  };
}
