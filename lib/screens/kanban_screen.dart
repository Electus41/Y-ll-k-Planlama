import 'package:flutter/material.dart';
import '../core/constants.dart';

class KanbanScreen extends StatefulWidget {
  const KanbanScreen({super.key});

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
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

  Future<void> _durumGuncelle(String id, String yeniDurum) async {
    await supabase
        .from('faaliyetler')
        .update({'durum': yeniDurum}).eq('id', id);
    setState(() {});
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
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent),
                  onPressed: () => Navigator.pop(context, true),
                  child:
                      const Text('Sil', style: TextStyle(color: Colors.white))),
            ],
          ),
        ) ??
        false;
    if (confirm) {
      await supabase.from('faaliyetler').delete().eq('id', id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _faaliyetEkleModalAc(
      {Map<String, dynamic>? mevcutFaaliyet}) async {
    List<String> dinamikBirimler = [];
    try {
      final data =
          await supabase.from('birimler').select('ad').order('created_at');
      dinamikBirimler = data.map((e) => e['ad'].toString()).toList();
    } catch (e) {
      debugPrint('Birimler çekilemedi: $e');
    }

    if (dinamikBirimler.isEmpty) {
      dinamikBirimler = ['Birim Bulunamadı (Önce Birim Ekleyin)'];
    }

    if (!mounted) return;

    final baslikController =
        TextEditingController(text: mevcutFaaliyet?['baslik'] ?? '');
    DateTime sTarih = DateTime.now();
    if (mevcutFaaliyet != null && mevcutFaaliyet['tarih'] != null) {
      try {
        final parts = mevcutFaaliyet['tarih'].toString().split(' ');
        if (parts.length == 3)
          sTarih = DateTime(int.parse(parts[2]), aylar.indexOf(parts[1]) + 1,
              int.parse(parts[0]));
      } catch (_) {}
    }
    String seciliGun = sTarih.day.toString();
    String seciliAy = aylar[sTarih.month - 1];
    String seciliYil = sTarih.year.toString();
    String durum = mevcutFaaliyet?['durum'] ?? 'Yapılacak';
    String oncelik = mevcutFaaliyet?['oncelik'] ?? 'Normal';

    String hedefBirim = mevcutFaaliyet?['hedef_birim'] ?? dinamikBirimler.first;
    if (!dinamikBirimler.contains(hedefBirim))
      hedefBirim = dinamikBirimler.first;

    String secilenSorumlu =
        mevcutFaaliyet?['olusturan_unvan'] ?? dinamikBirimler.first;
    if (!dinamikBirimler.contains(secilenSorumlu))
      secilenSorumlu = dinamikBirimler.first;

    bool isUpdate = mevcutFaaliyet != null;

    showDialog(
      context: context,
      builder: (modalContext) => Dialog(
        backgroundColor: const Color(0xFF161C1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.all(16),
        child: StatefulBuilder(
          builder: (context, setModalState) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isUpdate ? 'Görevi Düzenle' : 'Yeni Görev Ekle',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(context))
                    ]),
                const SizedBox(height: 16),
                TextField(
                    controller: baslikController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                        labelText: 'Görev Adı',
                        filled: true,
                        fillColor: const Color(0xFF1F2624),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none),
                        labelStyle: const TextStyle(color: Colors.white54))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: DropdownButtonFormField<String>(
                            value: seciliGun,
                            items: List.generate(31, (i) => (i + 1).toString())
                                .map((e) =>
                                    DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
                            onChanged: (val) =>
                                setModalState(() => seciliGun = val!),
                            dropdownColor: const Color(0xFF1F2624),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFF1F2624),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none)))),
                    const SizedBox(width: 4),
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
                            dropdownColor: const Color(0xFF1F2624),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFF1F2624),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none)))),
                    const SizedBox(width: 4),
                    Expanded(
                        child: DropdownButtonFormField<String>(
                            value: seciliYil,
                            items: ['2026', '2027', '2028', '2029']
                                .map((e) =>
                                    DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
                            onChanged: (val) =>
                                setModalState(() => seciliYil = val!),
                            dropdownColor: const Color(0xFF1F2624),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFF1F2624),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none)))),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                    value: hedefBirim,
                    items: dinamikBirimler
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setModalState(() => hedefBirim = val!),
                    dropdownColor: const Color(0xFF1F2624),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                        labelText: 'Sorumlu Birim / Komisyon',
                        filled: true,
                        fillColor: const Color(0xFF1F2624),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none),
                        labelStyle: const TextStyle(color: Colors.white54))),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                    value: secilenSorumlu,
                    items: dinamikBirimler
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) =>
                        setModalState(() => secilenSorumlu = val!),
                    dropdownColor: const Color(0xFF1F2624),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                        labelText: 'Görevi Oluşturan / Yetkili',
                        filled: true,
                        fillColor: const Color(0xFF1F2624),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none),
                        labelStyle: const TextStyle(color: Colors.white54))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: DropdownButtonFormField<String>(
                            value: durum,
                            items: ['Yapılacak', 'Yapılıyor', 'Tamamlandı']
                                .map((e) =>
                                    DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
                            onChanged: (val) =>
                                setModalState(() => durum = val!),
                            dropdownColor: const Color(0xFF1F2624),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                                labelText: 'Durum',
                                filled: true,
                                fillColor: const Color(0xFF1F2624),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none),
                                labelStyle:
                                    const TextStyle(color: Colors.white54)))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: DropdownButtonFormField<String>(
                            value: oncelik,
                            items: ['Acil', 'Normal', 'Düşük']
                                .map((e) =>
                                    DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
                            onChanged: (val) =>
                                setModalState(() => oncelik = val!),
                            dropdownColor: const Color(0xFF1F2624),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                                labelText: 'Öncelik',
                                filled: true,
                                fillColor: const Color(0xFF1F2624),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none),
                                labelStyle:
                                    const TextStyle(color: Colors.white54)))),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF69F0AE),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () async {
                    if (baslikController.text.isNotEmpty) {
                      String tarihStr = '$seciliGun $seciliAy $seciliYil';
                      if (isUpdate) {
                        await supabase.from('faaliyetler').update({
                          'baslik': baslikController.text,
                          'tarih': tarihStr,
                          'durum': durum,
                          'oncelik': oncelik,
                          'hedef_birim': hedefBirim,
                          'olusturan_unvan': secilenSorumlu
                        }).eq('id', mevcutFaaliyet['id']);
                      } else {
                        await supabase.from('faaliyetler').insert({
                          'baslik': baslikController.text,
                          'tarih': tarihStr,
                          'durum': durum,
                          'kategori': 'Eğitim',
                          'oncelik': oncelik,
                          'hedef_birim': hedefBirim,
                          'olusturan_unvan': secilenSorumlu
                        });
                      }
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      setState(() {});
                    }
                  },
                  child: const Text('Kaydet',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
          title: const Text('Kanban Panosu',
              style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF1B4D3E),
          iconTheme: const IconThemeData(color: Colors.white)),
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

          final faaliyetler = snapshot.data!;
          final yapilacaklar =
              faaliyetler.where((f) => f['durum'] == 'Yapılacak').toList();
          final yapilanlar =
              faaliyetler.where((f) => f['durum'] == 'Yapılıyor').toList();
          final tamamlananlar =
              faaliyetler.where((f) => f['durum'] == 'Tamamlandı').toList();

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _kanbanSutun(
                    context, 'Yapılacak', yapilacaklar, Colors.lightBlueAccent),
                const SizedBox(width: 12),
                _kanbanSutun(
                    context, 'Yapılıyor', yapilanlar, Colors.orangeAccent),
                const SizedBox(width: 12),
                _kanbanSutun(
                    context, 'Tamamlandı', tamamlananlar, Colors.greenAccent),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF69F0AE),
        foregroundColor: Colors.black,
        onPressed: () => _faaliyetEkleModalAc(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _kanbanSutun(BuildContext context, String baslik,
      List<Map<String, dynamic>> liste, Color renk) {
    return Expanded(
      child: DragTarget<Map<String, dynamic>>(
        onAccept: (item) {
          if (item['durum'] != baslik)
            _durumGuncelle(item['id'].toString(), baslik);
        },
        builder: (context, candidateData, rejectedData) {
          return Container(
            decoration: BoxDecoration(
                color: const Color(0xFF1A2220),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: candidateData.isNotEmpty
                        ? renk
                        : Colors.white.withValues(alpha: 0.1),
                    width: candidateData.isNotEmpty ? 2 : 1)),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: renk.withValues(alpha: 0.15),
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12))),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(baslik,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: renk,
                                fontSize: 15)),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: renk.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(10)),
                            child: Text('${liste.length}',
                                style: TextStyle(
                                    color: renk,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)))
                      ]),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: liste.length,
                    itemBuilder: (context, index) {
                      final item = liste[index];
                      return Draggable<Map<String, dynamic>>(
                        data: item,
                        feedback: Material(
                            color: Colors.transparent,
                            child: SizedBox(
                                width:
                                    MediaQuery.of(context).size.width / 3 - 24,
                                child:
                                    _gorevKarti(item, renk, isDragging: true))),
                        childWhenDragging: Opacity(
                            opacity: 0.3, child: _gorevKarti(item, renk)),
                        child: _gorevKarti(item, renk),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _gorevKarti(Map<String, dynamic> item, Color renk,
      {bool isDragging = false}) {
    return Card(
      color: const Color(0xFF222B29),
      elevation: isDragging ? 8 : 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
              color: isDragging ? renk : Colors.white.withValues(alpha: 0.05),
              width: isDragging ? 2 : 1)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item['baslik'] ?? '',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('📅 ${item['tarih'] ?? ''}',
                  style: const TextStyle(fontSize: 11, color: Colors.white54)),
              Text('👤 ${item['olusturan_unvan'] ?? ''}',
                  style:
                      const TextStyle(fontSize: 11, color: Colors.tealAccent))
            ]),
            if (!isDragging) ...[
              const Divider(color: Colors.white12, height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                      onTap: () => _faaliyetEkleModalAc(mevcutFaaliyet: item),
                      child: const Icon(Icons.edit,
                          size: 16, color: Colors.blueAccent)),
                  const SizedBox(width: 16),
                  InkWell(
                      onTap: () => _faaliyetSil(item['id'].toString()),
                      child: const Icon(Icons.delete,
                          size: 16, color: Colors.redAccent)),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }
}
