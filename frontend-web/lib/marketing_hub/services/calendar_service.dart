import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';

class CalendarService {
  static Future<http.Response> fetchCampaigns({required int year, required int month}) {
    return http.get(Uri.parse('$backendUrl/calendar/campaigns?year=$year&month=$month')).timeout(const Duration(seconds: 10));
  }

  static Future<http.Response> fetchNotes({required int year, required int month}) {
    return http.get(Uri.parse('$backendUrl/calendar/notes?year=$year&month=$month')).timeout(const Duration(seconds: 10));
  }

  static Future<http.Response> fetchCampaignsForYear(int year) {
    return http.get(Uri.parse('$backendUrl/calendar/campaigns/year?year=$year')).timeout(const Duration(seconds: 15));
  }

  static Future<http.Response> fetchNotesForYear(int year) {
    return http.get(Uri.parse('$backendUrl/calendar/notes/year?year=$year')).timeout(const Duration(seconds: 15));
  }

  static Future<http.Response> addNote({required String date, required String text, required String category}) {
    return http.post(
      Uri.parse('$backendUrl/calendar/notes'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'date': date, 'text': text, 'category': category}),
    );
  }

  static Future<http.Response> deleteNote(String noteId) {
    return http.delete(Uri.parse('$backendUrl/calendar/notes/$noteId'));
  }
}
