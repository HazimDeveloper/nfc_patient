import 'package:flutter/material.dart';

class CommonWidgets {
  // Show a loading dialog
  static void showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text(message ?? 'Please wait...'),
          ],
        ),
      ),
    );
  }
  
  // Show a success dialog
  static void showSuccessDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onPressed,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
            ),
            SizedBox(width: 10),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: onPressed ?? () => Navigator.pop(context),
            child: Text(buttonText ?? 'OK'),
          ),
        ],
      ),
    );
  }
  
  // Show an error dialog
  static void showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onPressed,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.error,
              color: Colors.red,
            ),
            SizedBox(width: 10),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: onPressed ?? () => Navigator.pop(context),
            child: Text(buttonText ?? 'OK'),
          ),
        ],
      ),
    );
  }
  
  // Show a confirmation dialog
  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmButtonText,
    String? cancelButtonText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelButtonText ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmButtonText ?? 'Confirm'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }
  
  // Custom text field
  static Widget buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
    int? maxLines = 1,
    IconData? prefixIcon,
    Widget? suffix,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffix: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: validator,
    );
  }
  
  // Build a card with title and content
  static Widget buildCard({
    required String title,
    required Widget content,
    IconData? icon,
    Color? iconColor,
    EdgeInsets? padding,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    color: iconColor,
                  ),
                  SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Divider(),
            SizedBox(height: 8),
            content,
          ],
        ),
      ),
    );
  }
  
  // Build a section header
  static Widget buildSectionHeader(
    BuildContext context, {
    required String title,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: Theme.of(context).primaryColor,
              size: 20,
            ),
            SizedBox(width: 8),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }
  
  // Build an info row (label: value)
  static Widget buildInfoRow({
    required String label,
    required String value,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 18,
              color: Colors.grey[600],
            ),
            SizedBox(width: 8),
          ],
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}