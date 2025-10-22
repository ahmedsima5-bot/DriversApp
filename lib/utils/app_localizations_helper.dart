import 'package:flutter/material.dart';

class AppLocalizationsHelper {
  static dynamic of(BuildContext context) {
    return _AppLocalizations();
  }
}

class _AppLocalizations {
  // صفحة طالب الخدمة
  String get requesterDashboard => "لوحة مقدم الطلبات";
  String get welcomeToRequests => "مرحباً بك في لوحة تقديم الطلبات";
  String get logout => "تسجيل الخروج";
  String get companyId => "معرف الشركة";
  String get userId => "معرف المستخدم";
  String get userName => "اسم المستخدم";
  String get userInfo => "معلومات المستخدم";
  String get createNewRequest => "إنشاء طلب جديد";
  String get trackMyRequests => "متابعة طلباتي";
  String get confirmLogout => "تسجيل الخروج";
  String get logoutMessage => "هل أنت متأكد أنك تريد تسجيل الخروج؟";
  String get cancel => "إلغاء";
  String get yes => "نعم";

  // صفحة السائق (إذا محتاجها)
  String get driverDashboard => "شاشة السائق - مهامي اليومية";
  String get welcome => "مرحباً بك";
  String get accountActive => "حسابك مفعل وجاهز لاستقبال الطلبات";
  String get accountNeedsActivation => "يجب تفعيل حساب السائق لبدء الاستخدام";
  String get activateDriverAccount => "تفعيل حساب السائق";
  String get noRequests => "لا توجد طلبات حالياً";
  String get requestsWillAppear => "سيتم عرض الطلبات هنا عندما يتم تخصيصها لك";
  String get viewMyRequests => "عرض طلباتي";
  String get profile => "الملف الشخصي";
  String get noAssignedRequests => "لا توجد طلبات مخصصة لك حالياً";
  String get accountActivated => "🎉 تم تفعيل حساب السائق بنجاح!";
  String get rideStarted => "🚗 بدأت الرحلة بنجاح";
  String get rideCompleted => "✅ تم إنهاء الرحلة بنجاح";
  String get driverId => "رقم السائق";
  String get driverStatus => "سائق - مرتبط بالموارد البشرية";
  String get startRide => "بدء الرحلة";
  String get completeRide => "إنهاء الرحلة";
  String get requestDetails => "تفاصيل الطلب";
  String get requestNumber => "رقم الطلب";
  String get customer => "العميل";
  String get from => "من";
  String get to => "إلى";
  String get priority => "الأولوية";
  String get myRequests => "طلباتي";
  String get totalRequests => "إجمالي الطلبات";
  String get diagnoseSystem => "تشخيص نظام التوزيع";
  String get systemDiagnosed => "تم تشخيص نظام التوزيع - شاهد الـ logs";
  String get refresh => "تحديث";
  String get close => "إغلاق";
  String get ok => "حسناً";
  String get name => "الاسم";
  String get email => "البريد";
  String get status => "الحالة";
}