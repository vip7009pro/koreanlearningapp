import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { vocabularyApi, aiAdminApi } from '../lib/api';
import { useState } from 'react';
import toast from 'react-hot-toast';
import { FiPlus, FiTrash2, FiUpload, FiEdit2, FiCopy, FiCpu, FiFolderPlus } from 'react-icons/fi';

export default function SpecializedVocabPage() {
  const queryClient = useQueryClient();
  const [activeCategory, setActiveCategory] = useState('');

  // Dynamic categories query
  const { data: categories = [], refetch: refetchCategories } = useQuery({
    queryKey: ['vocabCategories'],
    queryFn: () => vocabularyApi.getCategories().then((r) => r.data as { id: string; name: string; displayName: string }[]),
  });

  const activeCatName = activeCategory || categories[0]?.name || 'IT';

  const [vocabForm, setVocabForm] = useState({
    id: '', // Empty means creating new
    korean: '',
    vietnamese: '',
    pronunciation: '',
    difficulty: 'EASY',
    exampleSentence: '',
    exampleMeaning: '',
  });
  const [showForm, setShowForm] = useState(false);
  const [showImport, setShowImport] = useState(false);
  const [importJson, setImportJson] = useState('');
  const [importing, setImporting] = useState(false);
  const [showPrompt, setShowPrompt] = useState(false);
  const [promptText, setPromptText] = useState('');
  const [selectedVocabIds, setSelectedVocabIds] = useState<string[]>([]);

  // Add Category State
  const [showAddCategory, setShowAddCategory] = useState(false);
  const [newCatName, setNewCatName] = useState('');
  const [newCatDisplayName, setNewCatDisplayName] = useState('');

  // Gen AI State
  const [showGenAI, setShowGenAI] = useState(false);
  const [genCount, setGenCount] = useState(10);
  const [genProvider, setGenProvider] = useState('google');
  const [genModel, setGenModel] = useState('');
  const [generating, setGenerating] = useState(false);

  const handleGenAI = async () => {
    setGenerating(true);
    try {
      const res = await aiAdminApi.generateSpecializedVocabulary(
        activeCatName,
        genCount,
        genProvider,
        genModel || undefined
      );
      toast.success(`Đã tự động sinh và thêm ${res.data.inserted} từ vựng mới!`);
      invalidate();
      setShowGenAI(false);
    } catch (e: any) {
      toast.error('Lỗi khi sinh từ vựng: ' + (e?.response?.data?.message || e.message));
    } finally {
      setGenerating(false);
    }
  };

  const { data: modelsData, isLoading: isLoadingModels } = useQuery({
    queryKey: ['ai-models', genProvider],
    queryFn: () => aiAdminApi.listModels(genProvider).then((r) => r.data),
    enabled: showGenAI,
  });

  const modelsList = modelsData?.models || [];

  const { data: vocabList, isLoading } = useQuery({
    queryKey: ['vocab', 'category', activeCatName],
    queryFn: () => vocabularyApi.getByCategory(activeCatName).then((r) => r.data.data),
  });

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ['vocab', 'category', activeCatName] });
  };

  const createCategoryMutation = useMutation({
    mutationFn: (data: { name: string; displayName: string }) => vocabularyApi.createCategory(data),
    onSuccess: () => {
      refetchCategories();
      toast.success('Đã thêm chuyên ngành mới');
      setShowAddCategory(false);
      setNewCatName('');
      setNewCatDisplayName('');
    },
    onError: (e: any) => {
      toast.error('Có lỗi xảy ra: ' + (e?.response?.data?.message || e.message));
    },
  });

  const deleteCategoryMutation = useMutation({
    mutationFn: (id: string) => vocabularyApi.deleteCategory(id),
    onSuccess: () => {
      refetchCategories();
      toast.success('Đã xóa chuyên ngành');
      setActiveCategory('');
    },
    onError: (e: any) => {
      toast.error('Có lỗi xảy ra: ' + (e?.response?.data?.message || e.message));
    },
  });

  const createOrUpdateVocab = useMutation({
    mutationFn: (data: typeof vocabForm) => {
      const payload = {
        korean: data.korean,
        vietnamese: data.vietnamese,
        pronunciation: data.pronunciation,
        difficulty: data.difficulty,
        exampleSentence: data.exampleSentence,
        exampleMeaning: data.exampleMeaning,
        category: activeCatName,
      };
      if (data.id) {
        return vocabularyApi.update(data.id, payload);
      } else {
        return vocabularyApi.create(payload);
      }
    },
    onSuccess: () => {
      invalidate();
      toast.success(vocabForm.id ? 'Cập nhật thành công' : 'Thêm từ vựng thành công');
      setShowForm(false);
      resetForm();
    },
    onError: (e: any) => {
      toast.error('Có lỗi xảy ra: ' + (e?.response?.data?.message || e.message));
    },
  });

  const deleteVocab = useMutation({
    mutationFn: (id: string) => vocabularyApi.delete(id),
    onSuccess: () => {
      invalidate();
      toast.success('Đã xóa');
    },
  });

  const bulkDeleteVocab = useMutation({
    mutationFn: (ids: string[]) => vocabularyApi.bulkDelete(ids),
    onSuccess: (r: any, variables) => {
      invalidate();
      setSelectedVocabIds([]);
      toast.success(`Đã xóa ${(r?.data?.deleted ?? variables.length) as number} từ vựng`);
    },
  });

  const resetForm = () => {
    setVocabForm({
      id: '',
      korean: '',
      vietnamese: '',
      pronunciation: '',
      difficulty: 'EASY',
      exampleSentence: '',
      exampleMeaning: '',
    });
  };

  const handleEdit = (vocab: any) => {
    setVocabForm({
      id: vocab.id,
      korean: vocab.korean || '',
      vietnamese: vocab.vietnamese || '',
      pronunciation: vocab.pronunciation || '',
      difficulty: vocab.difficulty || 'EASY',
      exampleSentence: vocab.exampleSentence || '',
      exampleMeaning: vocab.exampleMeaning || '',
    });
    setShowForm(true);
    setShowImport(false);
    setShowPrompt(false);
  };

  const handleBulkImport = async () => {
    if (!importJson.trim()) return;
    setImporting(true);
    try {
      const items = JSON.parse(importJson);
      if (!Array.isArray(items)) {
        toast.error('JSON phải là một mảng []');
        setImporting(false);
        return;
      }
      await vocabularyApi.createBulk(
        items.map((v: any) => ({
          ...v,
          category: activeCatName,
        }))
      );
      toast.success(`Đã nhập thành công ${items.length} từ vựng!`);
      invalidate();
      setShowImport(false);
      setImportJson('');
    } catch (e: any) {
      toast.error('Lỗi nhập dữ liệu: ' + (e?.response?.data?.message || e.message));
    } finally {
      setImporting(false);
    }
  };

  const generatePrompt = () => {
    const activeLabel = categories.find((c) => c.name === activeCatName)?.displayName || activeCatName;
    const existingWords = ((vocabList as any[]) || []).map((v) => String(v.korean || '').trim()).filter(Boolean);
    const existingBlock = existingWords.length
      ? `\nKHÔNG ĐƯỢC tạo trùng với các từ tiếng Hàn đã có sẵn sau đây:\n${existingWords.map((x) => `- ${x}`).join('\n')}\n`
      : '';

    const prompt = `Bạn là chuyên gia ngôn ngữ tiếng Hàn. Hãy tạo danh sách 15-20 từ vựng chuyên ngành thuộc chủ đề: "${activeLabel}".
${existingBlock}
Chỉ trả về định dạng JSON là một mảng các đối tượng chứa thông tin từ vựng như ví dụ sau (không có bất kỳ lời giải thích, văn bản thừa hay định dạng markdown nào khác ngoài JSON):
[
  {
    "korean": "개발자",
    "vietnamese": "Nhà phát triển (lập trình viên)",
    "pronunciation": "gae-bal-ja",
    "exampleSentence": "그는 소프트웨어 개발자로 일하고 있습니다.",
    "exampleMeaning": "Anh ấy đang làm việc như một nhà phát triển phần mềm.",
    "difficulty": "MEDIUM"
  }
]

Lưu ý:
- "difficulty" chỉ nhận một trong 3 giá trị: "EASY", "MEDIUM", "HARD".
- Các câu ví dụ "exampleSentence" phải tự nhiên và phù hợp với từ chuyên ngành đó.`;

    setPromptText(prompt);
    setShowPrompt(true);
    setShowForm(false);
    setShowImport(false);
    setShowGenAI(false);
  };

  const copyPromptToClipboard = () => {
    navigator.clipboard.writeText(promptText).then(() => {
      toast.success('Đã sao chép prompt!');
    });
  };

  return (
    <div>
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-800">Từ vựng chuyên ngành 💼</h1>
          <p className="text-gray-500 mt-1">Quản lý từ vựng phân loại theo ngành nghề</p>
        </div>
        <div className="flex flex-wrap gap-2">
          <button
            onClick={() => {
              setShowGenAI(!showGenAI);
              setShowAddCategory(false);
              setShowForm(false);
              setShowImport(false);
              setShowPrompt(false);
            }}
            className="btn-secondary text-purple-700 border-purple-300 hover:bg-purple-50 flex items-center gap-2"
          >
            <FiCpu /> Gen AI 🤖
          </button>
          <button
            onClick={() => {
              setShowAddCategory(!showAddCategory);
              setShowGenAI(false);
              setShowForm(false);
              setShowImport(false);
              setShowPrompt(false);
            }}
            className="btn-secondary text-emerald-700 border-emerald-300 hover:bg-emerald-50 flex items-center gap-2"
          >
            <FiFolderPlus /> Thêm chuyên ngành 📁
          </button>
          <button onClick={generatePrompt} className="btn-secondary flex items-center gap-2">
            <FiCopy /> Copy Prompt AI
          </button>
          <button
            onClick={() => {
              setShowImport(!showImport);
              setShowGenAI(false);
              setShowAddCategory(false);
              setShowForm(false);
              setShowPrompt(false);
            }}
            className="btn-secondary flex items-center gap-2"
          >
            <FiUpload /> Import JSON
          </button>
          <button
            onClick={() => {
              resetForm();
              setShowForm(!showForm);
              setShowGenAI(false);
              setShowAddCategory(false);
              setShowImport(false);
              setShowPrompt(false);
            }}
            className="btn-primary flex items-center gap-2"
          >
            <FiPlus /> {showForm ? 'Đóng Form' : 'Thêm Từ mới'}
          </button>
        </div>
      </div>

      {/* Add Category Collapse */}
      {showAddCategory && (
        <div className="card mb-6 border border-emerald-200 bg-emerald-50">
          <h3 className="font-semibold text-emerald-800 mb-2">📁 Thêm chuyên ngành mới</h3>
          <div className="flex flex-col md:flex-row gap-3">
            <input
              type="text"
              placeholder="Tên chuyên ngành (VD: MEDICAL, TOURISM)"
              className="input flex-1 bg-white"
              value={newCatName}
              onChange={(e) => setNewCatName(e.target.value.toUpperCase())}
            />
            <input
              type="text"
              placeholder="Tên hiển thị (VD: Y học, Du lịch)"
              className="input flex-1 bg-white"
              value={newCatDisplayName}
              onChange={(e) => setNewCatDisplayName(e.target.value)}
            />
            <div className="flex gap-2">
              <button
                onClick={() => createCategoryMutation.mutate({ name: newCatName, displayName: newCatDisplayName })}
                className="btn-primary bg-emerald-600 hover:bg-emerald-700"
                disabled={createCategoryMutation.isPending}
              >
                {createCategoryMutation.isPending ? 'Đang lưu...' : 'Lưu'}
              </button>
              <button
                onClick={() => setShowAddCategory(false)}
                className="btn-secondary"
              >
                Hủy
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Gen AI Collapse */}
      {showGenAI && (
        <div className="card mb-6 border-2 border-purple-200 bg-purple-50">
          <h3 className="font-semibold text-purple-800 mb-2 flex items-center gap-2">
            <FiCpu /> Tự động sinh từ vựng AI cho danh mục: {activeCatName}
          </h3>
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 items-end">
            <div>
              <label className="block text-xs font-semibold text-purple-700 mb-1">Số lượng từ vựng</label>
              <input
                type="number"
                min={1}
                max={50}
                className="input w-full bg-white"
                value={genCount}
                onChange={(e) => setGenCount(Math.max(1, Number(e.target.value)))}
              />
            </div>
            <div>
              <label className="block text-xs font-semibold text-purple-700 mb-1">AI Provider</label>
              <select
                className="input w-full bg-white"
                value={genProvider}
                onChange={(e) => setGenProvider(e.target.value)}
              >
                <option value="google">Google Gemini</option>
                <option value="openrouter">OpenRouter (Claude/GPT...)</option>
              </select>
            </div>
            <div>
              <label className="block text-xs font-semibold text-purple-700 mb-1">AI Model (Tùy chọn)</label>
              <select
                className="input w-full bg-white"
                value={genModel}
                onChange={(e) => setGenModel(e.target.value)}
                disabled={isLoadingModels}
              >
                <option value="">(default)</option>
                {modelsList.map((m: any) => (
                  <option key={m.id} value={m.id}>
                    {m.label}
                  </option>
                ))}
              </select>
            </div>
            <div className="flex gap-2">
              <button
                onClick={handleGenAI}
                disabled={generating}
                className="btn-primary w-full bg-purple-600 hover:bg-purple-700 flex items-center justify-center gap-2"
              >
                {generating ? (
                  <span>Đang sinh...</span>
                ) : (
                  <>
                    <FiCpu /> Bắt đầu sinh
                  </>
                )}
              </button>
              <button
                onClick={() => setShowGenAI(false)}
                disabled={generating}
                className="btn-secondary"
              >
                Đóng
              </button>
            </div>
          </div>
          {generating && (
            <p className="text-xs text-purple-600 mt-2 animate-pulse">
              Hệ thống đang gọi AI để sinh từ vựng tiếng Hàn chuyên ngành tự nhiên, dịch nghĩa và làm ví dụ. Vui lòng đợi trong vài giây...
            </p>
          )}
        </div>
      )}

      {/* Categories Tabs */}
      <div className="flex flex-wrap gap-1 mb-6 bg-gray-100 rounded-lg p-1">
        {categories.map((cat: any) => (
          <button
            key={cat.id}
            onClick={() => {
              setActiveCategory(cat.name);
              setSelectedVocabIds([]);
              setShowForm(false);
              setShowImport(false);
              setShowPrompt(false);
              setShowGenAI(false);
              setShowAddCategory(false);
            }}
            className={`flex items-center justify-between px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
              activeCatName === cat.name ? 'bg-white shadow text-primary-600' : 'text-gray-600 hover:text-gray-800'
            }`}
          >
            <span>{cat.displayName}</span>
            {activeCatName === cat.name && (
              <span
                onClick={(e) => {
                  e.stopPropagation();
                  if (confirm(`CẢNH BÁO: Xóa chuyên ngành "${cat.displayName}" sẽ xóa vĩnh viễn tất cả từ vựng của chuyên ngành này. Bạn có chắc chắn?`)) {
                    deleteCategoryMutation.mutate(cat.id);
                  }
                }}
                className="ml-2 text-red-500 hover:text-red-700 transition-colors p-1 hover:bg-red-50 rounded"
                title="Xóa chuyên ngành"
              >
                <FiTrash2 className="inline w-3 h-3" />
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Prompt Modal */}
      {showPrompt && (
        <div className="card mb-6 border-2 border-indigo-200 bg-indigo-50">
          <div className="flex justify-between items-center mb-3">
            <h3 className="font-semibold text-indigo-800">📋 Prompt AI cho danh mục {activeCatName}</h3>
            <div className="flex gap-2">
              <button onClick={copyPromptToClipboard} className="btn-primary flex items-center gap-2 text-sm">
                <FiCopy /> Copy Prompt
              </button>
              <button onClick={() => setShowPrompt(false)} className="btn-secondary text-sm">
                Đóng
              </button>
            </div>
          </div>
          <p className="text-xs text-indigo-600 mb-3">
            Sao chép prompt này dán vào ChatGPT / Gemini để nhận đầu ra định dạng JSON. Sau đó dùng tính năng "Import JSON" ở trên để lưu vào hệ thống.
          </p>
          <textarea className="input w-full font-mono text-xs bg-white" rows={10} value={promptText} readOnly />
        </div>
      )}

      {/* Import JSON */}
      {showImport && (
        <div className="card mb-6">
          <h3 className="font-semibold mb-2">Nhập từ vựng hàng loạt bằng JSON cho {activeCatName}</h3>
          <p className="text-xs text-gray-500 mb-3">Dán chuỗi mảng JSON chứa các từ vựng vào đây.</p>
          <textarea
            className="input w-full font-mono text-xs"
            rows={8}
            placeholder='[{"korean": "개발자", "vietnamese": "Lập trình viên", "pronunciation": "gae-bal-ja", "difficulty": "MEDIUM"}]'
            value={importJson}
            onChange={(e) => setImportJson(e.target.value)}
          />
          <div className="flex gap-2 mt-3">
            <button onClick={handleBulkImport} disabled={importing} className="btn-primary">
              {importing ? 'Đang lưu...' : 'Lưu dữ liệu'}
            </button>
            <button
              onClick={() => {
                setShowImport(false);
                setImportJson('');
              }}
              className="btn-secondary"
            >
              Hủy
            </button>
          </div>
        </div>
      )}

      {/* Add / Edit Form */}
      {showForm && (
        <form
          onSubmit={(e) => {
            e.preventDefault();
            createOrUpdateVocab.mutate(vocabForm);
          }}
          className="card mb-6 grid grid-cols-1 md:grid-cols-3 gap-3 border border-primary-200"
        >
          <div className="col-span-full">
            <h3 className="font-semibold text-primary-700">
              {vocabForm.id ? `Sửa từ vựng: ${vocabForm.korean}` : `Thêm từ vựng mới vào chuyên ngành ${activeCatName}`}
            </h3>
          </div>
          <div>
            <label className="label">Từ tiếng Hàn</label>
            <input
              className="input"
              value={vocabForm.korean}
              onChange={(e) => setVocabForm({ ...vocabForm, korean: e.target.value })}
              required
            />
          </div>
          <div>
            <label className="label">Nghĩa tiếng Việt</label>
            <input
              className="input"
              value={vocabForm.vietnamese}
              onChange={(e) => setVocabForm({ ...vocabForm, vietnamese: e.target.value })}
              required
            />
          </div>
          <div>
            <label className="label">Phiên âm</label>
            <input
              className="input"
              value={vocabForm.pronunciation}
              onChange={(e) => setVocabForm({ ...vocabForm, pronunciation: e.target.value })}
              required
            />
          </div>
          <div>
            <label className="label">Độ khó</label>
            <select
              className="input"
              value={vocabForm.difficulty}
              onChange={(e) => setVocabForm({ ...vocabForm, difficulty: e.target.value })}
            >
              <option value="EASY">EASY</option>
              <option value="MEDIUM">MEDIUM</option>
              <option value="HARD">HARD</option>
            </select>
          </div>
          <div>
            <label className="label">Ví dụ minh họa (Hàn)</label>
            <input
              className="input"
              value={vocabForm.exampleSentence}
              onChange={(e) => setVocabForm({ ...vocabForm, exampleSentence: e.target.value })}
            />
          </div>
          <div>
            <label className="label">Dịch câu ví dụ (Việt)</label>
            <input
              className="input"
              value={vocabForm.exampleMeaning}
              onChange={(e) => setVocabForm({ ...vocabForm, exampleMeaning: e.target.value })}
            />
          </div>
          <div className="col-span-full flex gap-2">
            <button type="submit" className="btn-primary" disabled={createOrUpdateVocab.isPending}>
              {createOrUpdateVocab.isPending ? 'Đang lưu...' : vocabForm.id ? 'Cập nhật' : 'Thêm mới'}
            </button>
            <button
              type="button"
              className="btn-secondary"
              onClick={() => {
                setShowForm(false);
                resetForm();
              }}
            >
              Hủy
            </button>
          </div>
        </form>
      )}

      {/* Vocab List */}
      {isLoading ? (
        <div className="text-center py-12 text-gray-500">Đang tải từ vựng...</div>
      ) : (
        <div className="card overflow-hidden p-0">
          {selectedVocabIds.length > 0 && (
            <div className="p-3 flex justify-between items-center bg-gray-50 border-b">
              <div className="text-sm text-gray-600">Đã chọn: {selectedVocabIds.length} mục</div>
              <button
                className="btn-secondary flex items-center gap-2 text-red-600 hover:bg-red-50"
                onClick={() => {
                  if (!confirm(`Bạn có chắc chắn muốn xóa ${selectedVocabIds.length} từ đã chọn?`)) return;
                  bulkDeleteVocab.mutate(selectedVocabIds);
                }}
                disabled={bulkDeleteVocab.isPending}
              >
                <FiTrash2 /> Xóa các mục đã chọn
              </button>
            </div>
          )}

          <table className="w-full">
            <thead className="bg-gray-50">
              <tr>
                <th className="table-header w-10">#</th>
                <th className="table-header w-10">
                  <input
                    type="checkbox"
                    checked={
                      selectedVocabIds.length > 0 && selectedVocabIds.length === ((vocabList as any[])?.length || 0)
                    }
                    onChange={(e) => {
                      if (e.target.checked) setSelectedVocabIds(((vocabList as any[]) || []).map((x) => x.id as string));
                      else setSelectedVocabIds([]);
                    }}
                  />
                </th>
                <th className="table-header">Từ tiếng Hàn</th>
                <th className="table-header">Nghĩa tiếng Việt</th>
                <th className="table-header">Phiên âm</th>
                <th className="table-header">Độ khó</th>
                <th className="table-header">Ví dụ minh họa</th>
                <th className="table-header w-24">Hành động</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {((vocabList as any[]) || []).length === 0 ? (
                <tr>
                  <td colSpan={8} className="text-center py-8 text-gray-400">
                    Chưa có từ vựng chuyên ngành trong danh mục này. Hãy thêm mới!
                  </td>
                </tr>
              ) : (
                (vocabList as any[])?.map((v, idx) => (
                  <tr key={v.id} className="hover:bg-gray-50">
                    <td className="table-cell text-xs text-gray-400">{idx + 1}</td>
                    <td className="table-cell">
                      <input
                        type="checkbox"
                        checked={selectedVocabIds.includes(v.id as string)}
                        onChange={(e) => {
                          const id = v.id as string;
                          if (e.target.checked) setSelectedVocabIds((prev) => Array.from(new Set([...prev, id])));
                          else setSelectedVocabIds((prev) => prev.filter((x) => x !== id));
                        }}
                      />
                    </td>
                    <td className="table-cell font-medium text-lg text-primary-700">{v.korean}</td>
                    <td className="table-cell">{v.vietnamese}</td>
                    <td className="table-cell text-gray-500 text-xs italic">{v.pronunciation}</td>
                    <td className="table-cell">
                      <span
                        className={`badge ${
                          v.difficulty === 'EASY'
                            ? 'badge-green'
                            : v.difficulty === 'MEDIUM'
                            ? 'badge-yellow'
                            : 'badge-red'
                        }`}
                      >
                        {v.difficulty}
                      </span>
                    </td>
                    <td className="table-cell text-xs text-gray-600 max-w-xs truncate" title={v.exampleSentence}>
                      {v.exampleSentence ? (
                        <>
                          <div className="font-semibold">{v.exampleSentence}</div>
                          <div className="text-gray-400">{v.exampleMeaning}</div>
                        </>
                      ) : (
                        <span className="text-gray-300">Không có</span>
                      )}
                    </td>
                    <td className="table-cell flex gap-2">
                      <button onClick={() => handleEdit(v)} className="text-primary-500 hover:text-primary-700">
                        <FiEdit2 size={14} />
                      </button>
                      <button
                        onClick={() => {
                          if (confirm('Xóa từ vựng chuyên ngành này?')) deleteVocab.mutate(v.id);
                        }}
                        className="text-gray-400 hover:text-red-500"
                      >
                        <FiTrash2 size={14} />
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
