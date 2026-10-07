class ApiResponse<T> {
  final String status;
  final T? data;
  final String? message;

  ApiResponse({
    required this.status,
    this.data,
    this.message,
  });

  bool get isSuccess => status == 'success';

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic data)? fromData,
  ) {
    return ApiResponse(
      status: json['status'] as String? ?? 'error',
      data: json['data'] != null && fromData != null
          ? fromData(json['data'])
          : json['data'] as T?,
      message: json['message'] as String?,
    );
  }
}
