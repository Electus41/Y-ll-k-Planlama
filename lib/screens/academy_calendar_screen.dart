import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../core/constants.dart';

class AcademyCalendarScreen extends StatefulWidget {
  const AcademyCalendarScreen({super.key});

  @override
  State<AcademyCalendarScreen> createState() => _AcademyCalendarScreenState();
}

class _AcademyCalendarScreenState extends State<AcademyCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String _secilenKademe = 'Tümü';
  CalendarFormat _calendarFormat = CalendarFormat.week;

  final List<String> _kademeler = [
    'Tümü',
    'İl Yürütme Kurulu',
    'İl Teşkilatlanma',
    'Üniversite Komisyonu',
    'Lise Komisyonu',
    'Medya ve Tanıtım',
    'Sosyal İşler',
    'Eğitim Birimi',
    'Hanımlar Komisyonu',
    'Ortaokul Komisyonu',
  ];

  final List<String> aylar = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    initializeDateFormatting('tr_TR', null);
  }

  // Veritabanındaki '24 Ekim 2026' string formatını DateTime'a çeviren yardımcı
  DateTime? _parseTarih(String? tarihStr) {
    if (tarihStr == null) return null;
    try {
      final parts = tarihStr.split(' ');
      if (parts.length == 3) {
        int day = int.parse(parts[0]);
        int month = aylar.indexOf(parts[1]) + 1;
        int year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  List<Map<String, dynamic>> _getEventsForDay(
      DateTime day, List<Map<String, dynamic>> tumFaaliyetler) {
    return tumFaaliyetler.where((event) {
      final eventDate = _parseTarih(event['tarih'].toString());
      if (eventDate == null) return false;

      final isSameDay = eventDate.year == day.year &&
          eventDate.month == day.month &&
          eventDate.day == day.day;

      if (!isSameDay) return false;
      if (_secilenKademe == 'Tümü') return true;
      return event['hedef_birim'] == _secilenKademe;
    }).toList();
  }

  Future<void> _faaliyetSil(String id) async {
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF161C1A),
            title: const Text('Silmek İstediğinize Emin Misiniz?',
                style: TextStyle(color: Colors.white)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('İptal',
                      style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sil', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await supabase.from('faaliyetler').delete().eq('id', id);
      if (mounted) setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Kayıt silindi.'), backgroundColor: Colors.red));
    }
  }

  void _faaliyetEkleModalAc({Map<String, dynamic>? mevcutFaaliyet}) {
    final baslikController =
        TextEditingController(text: mevcutFaaliyet?['baslik'] ?? '');

    DateTime sTarih = _selectedDay ?? DateTime.now();
    if (mevcutFaaliyet != null) {
      sTarih = _parseTarih(mevcutFaaliyet['tarih']) ?? DateTime.now();
    }

    String seciliGun = sTarih.day.toString();
    String seciliAy = aylar[sTarih.month - 1];
    String seciliYil = sTarih.year.toString();

    String durum = mevcutFaaliyet?['durum'] ?? 'Yapılacak';
    String hedefBirim = mevcutFaaliyet?['hedef_birim'] ?? 'İl Yürütme Kurulu';
    String oncelik = mevcutFaaliyet?['oncelik'] ?? 'Normal';
    bool isUpdate = mevcutFaaliyet != null;

    showDialog(
      context: context,
      builder: (modalContext) => Dialog(
        backgroundColor: const Color(0xFF121816),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: StatefulBuilder(
          builder: (context, setModalState) => SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isUpdate ? 'Faaliyeti Düzenle' : 'Yeni Faaliyet Ekle',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: baslikController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Faaliyet Adı',
                    filled: true,
                    fillColor: const Color(0xFF1A2220),
                    labelStyle: const TextStyle(color: Colors.white54),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: DropdownButtonFormField<String>(
                      value: seciliGun,
                      items: List.generate(31, (i) => (i + 1).toString())
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) => setModalState(() => seciliGun = val!),
                      dropdownColor: const Color(0xFF1A2220),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF1A2220),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none)),
                    )),
                    const SizedBox(width: 8),
                    Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: seciliAy,
                          items: aylar
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (val) =>
                              setModalState(() => seciliAy = val!),
                          dropdownColor: const Color(0xFF1A2220),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF1A2220),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none)),
                        )),
                    const SizedBox(width: 8),
                    Expanded(
                        child: DropdownButtonFormField<String>(
                      value: seciliYil,
                      items: ['2026', '2027', '2028', '2029']
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) => setModalState(() => seciliYil = val!),
                      dropdownColor: const Color(0xFF1A2220),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF1A2220),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none)),
                    )),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: hedefBirim,
                  items: _kademeler
                      .where((k) => k != 'Tümü')
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setModalState(() => hedefBirim = val!),
                  dropdownColor: const Color(0xFF1A2220),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                      labelText: 'Sorumlu Birim',
                      filled: true,
                      fillColor: const Color(0xFF1A2220),
                      labelStyle: const TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF69F0AE),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () async {
                    if (baslikController.text.isNotEmpty) {
                      String tarihStr = '$seciliGun $seciliAy $seciliYil';
                      if (isUpdate) {
                        await supabase.from('faaliyetler').update({
                          'baslik': baslikController.text,
                          'tarih': tarihStr,
                          'hedef_birim': hedefBirim
                        }).eq('id', mevcutFaaliyet['id']);
                      } else {
                        await supabase.from('faaliyetler').insert({
                          'baslik': baslikController.text,
                          'tarih': tarihStr,
                          'durum': durum,
                          'hedef_birim': hedefBirim,
                          'oncelik': oncelik,
                          'olusturan_unvan': 'Yönetici'
                        });
                      }
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      setState(() {});
                    }
                  },
                  child: const Text('Kaydet',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121816),
      appBar: AppBar(
        title: const Text('Planlama Takvimi',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF121816),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('faaliyetler')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false)
            .map((maps) => List<Map<String, dynamic>>.from(maps)),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF69F0AE)));

          final tumFaaliyetler = snapshot.data!;
          final seciliGunEtkinlikleri =
              _getEventsForDay(_selectedDay ?? _focusedDay, tumFaaliyetler);

          return Column(
            children: [
              Container(
                color: const Color(0xFF121816),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: TableCalendar(
                  locale: 'tr_TR',
                  firstDay: DateTime.utc(2025, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  availableCalendarFormats: const {
                    CalendarFormat.week: 'Haftalık',
                    CalendarFormat.month: 'Aylık'
                  },
                  onFormatChanged: (format) =>
                      setState(() => _calendarFormat = format),
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) => setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  }),
                  eventLoader: (day) => _getEventsForDay(day, tumFaaliyetler),
                  calendarStyle: CalendarStyle(
                    defaultTextStyle:
                        const TextStyle(color: Colors.white, fontSize: 14),
                    weekendTextStyle:
                        const TextStyle(color: Colors.white54, fontSize: 14),
                    outsideTextStyle:
                        const TextStyle(color: Colors.white24, fontSize: 14),
                    selectedDecoration: const BoxDecoration(
                        color: Color(0xFF69F0AE), shape: BoxShape.circle),
                    selectedTextStyle: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    todayDecoration: const BoxDecoration(
                        color: Color(0xFF1B4D3E), shape: BoxShape.circle),
                    todayTextStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    markerDecoration: const BoxDecoration(
                        color: Colors.orangeAccent, shape: BoxShape.circle),
                    markersMaxCount: 1,
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: true,
                    formatButtonDecoration: BoxDecoration(
                        color: const Color(0xFF1B4D3E),
                        borderRadius: BorderRadius.circular(10)),
                    formatButtonTextStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                    titleCentered: false,
                    titleTextStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                    leftChevronIcon: const Icon(Icons.chevron_left,
                        color: Colors.white70, size: 22),
                    rightChevronIcon: const Icon(Icons.chevron_right,
                        color: Colors.white70, size: 22),
                  ),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                      weekdayStyle:
                          TextStyle(color: Colors.white54, fontSize: 12),
                      weekendStyle:
                          TextStyle(color: Colors.white38, fontSize: 12)),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 24, left: 24, right: 24),
                  decoration: BoxDecoration(
                      color: const Color(0xFF1B4D3E),
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(32),
                          topRight: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withAlpha(80),
                            blurRadius: 15,
                            offset: const Offset(0, -5))
                      ]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                          child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(50),
                                  borderRadius: BorderRadius.circular(10)))),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  _selectedDay != null
                                      ? DateFormat('d MMMM yyyy', 'tr_TR')
                                          .format(_selectedDay!)
                                      : 'Tarih Seçilmedi',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              const Text('Planlanan Faaliyetler',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                          InkWell(
                            onTap: _faaliyetEkleModalAc,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                  color: const Color(0xFF121816),
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Row(children: [
                                Icon(Icons.add,
                                    color: Color(0xFF69F0AE), size: 18),
                                SizedBox(width: 4),
                                Text('Ekle',
                                    style: TextStyle(
                                        color: Color(0xFF69F0AE),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13))
                              ]),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _kademeler.map((kademe) {
                            bool isSelected = _secilenKademe == kademe;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(kademe),
                                selected: isSelected,
                                showCheckmark: false,
                                selectedColor: const Color(0xFF121816),
                                backgroundColor: const Color(0xFF153B2F),
                                labelStyle: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFF69F0AE)
                                        : Colors.white70,
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide.none),
                                onSelected: (bool selected) =>
                                    setState(() => _secilenKademe = kademe),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (seciliGunEtkinlikleri.isEmpty)
                        Expanded(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                              Icon(Icons.event_busy,
                                  size: 48, color: Colors.white.withAlpha(50)),
                              const SizedBox(height: 16),
                              const Center(
                                  child: Text('Bu tarihe ait kayıt bulunamadı.',
                                      style: TextStyle(
                                          color: Colors.white54, fontSize: 14)))
                            ]))
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: seciliGunEtkinlikleri.length,
                            itemBuilder: (context, index) {
                              final event = seciliGunEtkinlikleri[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: const Color(0xFF121816),
                                    borderRadius: BorderRadius.circular(12),
                                    border: const Border(
                                        left: BorderSide(
                                            color: Color(0xFF69F0AE),
                                            width: 4))),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(event['baslik'],
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15)),
                                          const SizedBox(height: 4),
                                          Text(
                                              '${event['hedef_birim']} - ${event['durum']}',
                                              style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                        icon: const Icon(Icons.edit,
                                            color: Colors.blueAccent, size: 20),
                                        onPressed: () => _faaliyetEkleModalAc(
                                            mevcutFaaliyet: event)),
                                    IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.redAccent, size: 20),
                                        onPressed: () => _faaliyetSil(
                                            event['id'].toString())),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
