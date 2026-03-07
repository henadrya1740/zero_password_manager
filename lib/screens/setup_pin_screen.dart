import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/colors.dart';

class SetupPinScreen extends StatefulWidget {
  const SetupPinScreen({super.key});

  @override
  State<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends State<SetupPinScreen> with TickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(
    4, 
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    4, 
    (index) => FocusNode(),
  );
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
    
    // Добавляем слушатели для автоматического перехода между полями
    for (int i = 0; i < 4; i++) {
      _controllers[i].addListener(() {
        if (_controllers[i].text.length == 1 && i < 3) {
          _focusNodes[i + 1].requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  void _onPinChanged() {
    setState(() {
      _pin = _controllers.map((controller) => controller.text).join();
      _errorMessage = null;
    });
    
    if (_pin.length == 4) {
      _proceedToConfirm();
    }
  }

  void _proceedToConfirm() {
    setState(() {
      _isConfirming = true;
    });
    
    // Очищаем поля для подтверждения
    for (var controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  void _onConfirmPinChanged() {
    setState(() {
      _confirmPin = _controllers.map((controller) => controller.text).join();
      _errorMessage = null;
    });
    
    if (_confirmPin.length == 4) {
      _savePin();
    }
  }

  Future<void> _savePin() async {
    if (_pin != _confirmPin) {
      setState(() {
        _errorMessage = 'PIN-коды не совпадают';
      });
      
      // Очищаем поля подтверждения
      for (var controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Сохраняем PIN-код в SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pin_code', _pin);
      
      // Показываем анимацию успеха
      _showSuccessAnimation();
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка сохранения PIN-кода';
        _isLoading = false;
      });
    }
  }

  void _showSuccessAnimation() {
    // Прямой переход к паролям без диалога
    Navigator.pushNamedAndRemoveUntil(
      context, 
      '/passwords', 
      (route) => false
    );
  }

  void _goBack() {
    if (_isConfirming) {
      setState(() {
        _isConfirming = false;
        _confirmPin = '';
      });
      
      // Очищаем поля
      for (var controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.text),
          onPressed: _goBack,
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Логотип
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.button.withOpacity(0.2),
                          AppColors.button.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.button.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isConfirming ? Icons.lock_outline : Icons.security,
                      size: 40,
                      color: AppColors.button,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Заголовок
                  Text(
                    _isConfirming ? 'Подтвердите PIN-код' : 'Установите PIN-код',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    _isConfirming 
                      ? 'Повторите ввод для подтверждения'
                      : 'Создайте 4-значный PIN-код для быстрого доступа',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Поля для PIN-кода
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(4, (index) {
                      return Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.input,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _focusNodes[index].hasFocus 
                              ? AppColors.button 
                              : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(1),
                          ],
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (value) => _isConfirming 
                            ? _onConfirmPinChanged() 
                            : _onPinChanged(),
                        ),
                      );
                    }),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Сообщение об ошибке
                  if (_errorMessage != null)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Индикатор загрузки
                  if (_isLoading)
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.button),
                    ),
                  
                  const SizedBox(height: 40),
                  
                  // Подсказка
                  const Text(
                    'PIN-код должен содержать 4 цифры',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Кнопка пропуска
                  if (!_isConfirming)
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context, 
                          '/passwords', 
                          (route) => false
                        );
                      },
                      child: const Text(
                        'Пропустить',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 